require "test_helper"

class EmblemaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { Rails.cache.delete("emblemas/total_usuarios") }

  # ---------------------------------------------------------------- Ícone

  test "sanitiza o SVG: script, handler e link externo saem; o desenho fica" do
    emblema = Emblema.create!(
      nome: "Perigoso", cor: "#00C55B", efeito: "nenhum",
      icone_svg: <<~SVG
        <svg viewBox="0 0 24 24" onload="alert(1)">
          <script>alert(2)</script>
          <a href="https://evil.example">link</a>
          <g transform="translate(2 2)"><path d="M0 0h20v20H0z" fill="currentColor"/></g>
          <circle cx="12" cy="12" r="9" stroke="currentColor" fill="none"/>
        </svg>
      SVG
    )

    assert_no_match(/script/i, emblema.icone_svg)
    assert_no_match(/alert/i, emblema.icone_svg)
    assert_no_match(/onload/i, emblema.icone_svg)
    assert_no_match(/evil\.example/, emblema.icone_svg)
    # o conteúdo legítimo sobrevive — sanitizar não pode esvaziar o ícone.
    # <g> importa: é como Figma e Illustrator exportam.
    assert_match(/<svg/, emblema.icone_svg)
    assert_match(/viewBox="0 0 24 24"/, emblema.icone_svg)
    assert_match(/<g transform=/, emblema.icone_svg)
    assert_match(/M0 0h20v20H0z/, emblema.icone_svg)
    assert_match(/<circle/, emblema.icone_svg)
  end

  test "SVG acima do teto é recusado" do
    emblema = Emblema.new(nome: "Gigante", cor: "#00C55B", efeito: "nenhum",
                          icone_svg: "<svg>#{'a' * Emblema::TAMANHO_MAX_SVG}</svg>")

    assert_not emblema.valid?
    assert emblema.errors[:icone_svg].any?
  end

  test "cor precisa ser hexadecimal de 6 dígitos" do
    emblema = emblemas(:primeira_novidade)

    assert_not emblema.update(cor: "vermelho")
    assert_not emblema.update(cor: "#GGG")
    assert emblema.update(cor: "#1D84F5")
  end

  # ------------------------------------------------------------- Raridade

  test "a raridade sai do % de donos, e o corte de cada faixa é exclusivo" do
    emblema = emblemas(:veterano)

    # com 100 contas cada contagem vira o percentual direto, então os limites
    # das faixas ficam exatos em vez de aproximados
    com_total_de_usuarios(100) do
      {
        0 => "lendario",
        2 => "lendario",  # 2% NÃO é > 2 → continua lendário
        3 => "epico",
        10 => "epico",    # 10% não é > 10
        11 => "raro",
        25 => "raro",
        26 => "incomum",
        50 => "incomum",  # metade das contas ainda não é "comum"
        51 => "comum",
        100 => "comum"
      }.each do |donos, esperado|
        emblema.update_column(:usuarios_count, donos)
        assert_equal esperado, emblema.reload.raridade, "#{donos}% deveria ser #{esperado}"
      end
    end
  end

  test "o percentual mostrado e a faixa nunca se contradizem" do
    # 21/209 = 10,0478…% → mostra "10,0%", então a faixa tem que ser a de
    # ATÉ 10% (épico). Arredondar antes de faixar é o que garante isso.
    emblema = emblemas(:veterano)
    emblema.update_column(:usuarios_count, 21)

    com_total_de_usuarios(209) do
      assert_equal 10.0, emblema.reload.percentual
      assert_equal "epico", emblema.raridade
    end
  end

  test "sem nenhuma conta, o percentual é zero em vez de divisão por zero" do
    User.delete_all
    Rails.cache.delete("emblemas/total_usuarios")

    assert_equal 0.0, emblemas(:veterano).percentual
    assert_equal "lendario", emblemas(:veterano).raridade
  end

  # ------------------------------------------------------------ Concessão

  test "conceder! é idempotente: a segunda vez devolve nil e não duplica" do
    emblema = emblemas(:veterano)
    ana = users(:ana)

    assert_difference -> { EmblemaUsuario.count }, 1 do
      assert emblema.conceder!(ana, origem: "concessao")
    end
    assert_no_difference -> { EmblemaUsuario.count } do
      assert_nil emblema.conceder!(ana, origem: "concessao")
    end
  end

  test "conceder! mantém o contador de donos (raridade) em dia" do
    emblema = emblemas(:veterano)

    assert_difference -> { emblema.reload.usuarios_count }, 1 do
      emblema.conceder!(users(:ana), origem: "concessao")
    end
    assert_difference -> { emblema.reload.usuarios_count }, -1 do
      emblema.revogar!(users(:ana))
    end
  end

  test "conceder! enfileira o cargo do Discord só quando o emblema tem cargo" do
    assert_enqueued_with job: DiscordCargoJob do
      emblemas(:convidado_beta).conceder!(users(:ana), origem: "convite")
    end

    # emblema sem cargo cadastrado não enfileira nada. Escolhido explicitamente
    # por NÃO ter discord_role_id nas fixtures — o veterano passou a ter um
    # quando a sincronização entrou, e servia de exemplo do caso oposto.
    sem_cargo = emblemas(:primeira_novidade)
    assert_nil sem_cargo.discord_role_id, "a premissa deste teste é o emblema sem cargo"
    assert_no_enqueued_jobs only: DiscordCargoJob do
      sem_cargo.conceder!(users(:diretor), origem: "concessao")
    end
  end

  # O job recebe o ROLE_ID, não o emblema: rank e elo também dão cargo, e
  # "sai o cargo do prata, entra o do ouro" não cabe num id de emblema.
  test "revogar! tira o cargo do Discord junto" do
    emblemas(:convidado_beta).conceder!(users(:ana), origem: "convite")
    cargo = emblemas(:convidado_beta).discord_role_id

    assert_enqueued_with job: DiscordCargoJob, args: [ users(:ana).id, cargo, "remover" ] do
      emblemas(:convidado_beta).revogar!(users(:ana))
    end
  end

  # -------------------------------------------------------------- Critério

  test "avaliar! concede só o emblema cuja meta foi batida" do
    elisa = users(:escritor_user) # já tem 'primeira_novidade' pela fixture

    Emblema.avaliar!(elisa)

    assert_not elisa.emblemas.reload.include?(emblemas(:veterano)),
               "1000 dias de conta não pode cair para uma conta recém-criada"
    # emblema sem critério nunca entra pela varredura
    assert_not elisa.emblemas.include?(emblemas(:fundador_honorario))
  end

  test "avaliar! concede quando o usuário alcança a meta" do
    ana = users(:ana)
    emblema = Emblema.create!(nome: "Bem-vindo", cor: "#00C55B", efeito: "nenhum",
                              icone_svg: "<svg viewBox='0 0 24 24'><circle cx='12' cy='12' r='9'/></svg>",
                              criterio: "dias_de_conta", meta: 0 + 1)
    ana.update_column(:created_at, 5.days.ago)

    assert_difference -> { ana.emblemas.count }, 1 do
      Emblema.avaliar!(ana)
    end
    assert_includes ana.emblemas.reload, emblema
  end

  test "avaliar! não faz nada com o recurso desligado" do
    Setting.ativar!("emblemas_ativos", false)
    ana = users(:ana)
    Emblema.create!(nome: "Bem-vindo", cor: "#00C55B", efeito: "nenhum",
                    icone_svg: "<svg viewBox='0 0 24 24'><circle cx='12' cy='12' r='9'/></svg>",
                    criterio: "dias_de_conta", meta: 1)
    ana.update_column(:created_at, 5.days.ago)

    assert_no_difference -> { EmblemaUsuario.count } do
      Emblema.avaliar!(ana)
    end
  ensure
    Setting.ativar!("emblemas_ativos", true)
  end

  test "emblema inativo não é concedido pela varredura" do
    emblemas(:aposentado).update!(criterio: "dias_de_conta", meta: 1)
    users(:ana).update_column(:created_at, 5.days.ago)

    Emblema.avaliar!(users(:ana))

    assert_not users(:ana).emblemas.reload.include?(emblemas(:aposentado))
  end

  test "critério exige meta e meta exige critério" do
    base = { nome: "X", cor: "#00C55B", efeito: "nenhum", icone_svg: "<svg viewBox='0 0 24 24'></svg>" }

    assert_not Emblema.new(**base, criterio: "comentarios").valid?
    assert_not Emblema.new(**base, meta: 5).valid?
    assert Emblema.new(**base, criterio: "comentarios", meta: 5).valid?
    assert Emblema.new(**base).valid?, "emblema só de concessão é válido sem critério"
  end

  test "todo critério do registro roda sem explodir" do
    Emblema::CRITERIOS.each do |chave, config|
      assert_kind_of Integer, config[:conta].call(users(:escritor_user)),
                     "critério #{chave} deveria devolver um número"
    end
  end

  # -------------------------------------------------------------- Equipar

  test "só dá para equipar emblema desbloqueado" do
    ana = users(:ana) # tem fundador_honorario, não tem veterano

    assert_not ana.update(emblema_destaque: emblemas(:veterano))
    assert ana.update(emblema_destaque: emblemas(:fundador_honorario))
  end

  test "destaque e secundário não podem ser o mesmo" do
    ana = users(:ana)

    assert_not ana.update(emblema_destaque: emblemas(:fundador_honorario),
                          emblema_secundario: emblemas(:fundador_honorario))
  end

  private

  # O cache é :null_store em teste, então escrever a chave não segura nada:
  # troca o método na mão (mesma técnica do discord_webhook_job_test).
  def com_total_de_usuarios(total)
    original = Emblema.method(:total_usuarios)
    Emblema.define_singleton_method(:total_usuarios) { total }
    yield
  ensure
    Emblema.define_singleton_method(:total_usuarios, original)
  end
end
