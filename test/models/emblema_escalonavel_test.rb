require "test_helper"

# Emblema escalonável: rank por limiar, registros com descrição e data, teto de
# donos e a pontuação de elo que sai daí.
class EmblemaEscalonavelTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { Rails.cache.delete("emblemas/total_usuarios") }

  # ------------------------------------------------------- Rank por registro

  test "cada registro acumula e o rank sobe ao cruzar o limiar" do
    maratonista = emblemas(:maratonista)
    dario = users(:diretor)

    # 1º registro → bronze (limiar 1)
    maratonista.conceder!(dario, origem: "concessao", descricao: "Maratona A")
    vinculo = maratonista.emblema_usuarios.find_by(user: dario)
    assert_equal "Bronze", vinculo.nivel.nome
    assert_equal 1, vinculo.conquistas_count

    # 2º → prata (limiar 2)
    maratonista.conceder!(dario, origem: "concessao", descricao: "Maratona B")
    assert_equal "Prata", vinculo.reload.nivel.nome

    # 3º ainda prata: ouro só em 4
    maratonista.conceder!(dario, origem: "concessao", descricao: "Maratona C")
    assert_equal "Prata", vinculo.reload.nivel.nome

    # 4º → ouro
    maratonista.conceder!(dario, origem: "concessao", descricao: "Maratona D")
    assert_equal "Ouro", vinculo.reload.nivel.nome
    assert_equal 4, vinculo.conquistas_count
  end

  test "cada registro guarda a própria descrição e data — é o que o hover lista" do
    vinculo = emblema_usuarios(:ana_maratonista)

    assert_equal [ "Maratona Interna 2026", "Maratona SBC 2025" ],
                 vinculo.conquistas.recentes.map(&:descricao)
    assert vinculo.conquistas.all? { |c| c.ocorrido_em.present? }
  end

  test "data retroativa é aceita; data futura não" do
    maratonista = emblemas(:maratonista)

    maratonista.conceder!(users(:diretor), origem: "concessao",
                          descricao: "Maratona de 2020", ocorrido_em: 5.years.ago)
    assert_equal 5.years.ago.to_date,
                 maratonista.emblema_usuarios.find_by(user: users(:diretor))
                            .conquistas.first.ocorrido_em.to_date

    assert_raises(ActiveRecord::RecordInvalid) do
      maratonista.conceder!(users(:membro_user), origem: "concessao", ocorrido_em: 1.day.from_now)
    end
  end

  test "emblema único não acumula: o segundo registro é no-op" do
    unico = emblemas(:fundador_honorario)

    assert_nil unico.conceder!(users(:ana), origem: "concessao")
    assert_equal 1, emblema_usuarios(:ana_fundadora).reload.conquistas_count
  end

  # -------------------------------------------------------- Rank por métrica

  test "escalonável de métrica acompanha o critério sem registrar evento" do
    pensador = emblemas(:pensador) # ideias_aprovadas: bronze em 1, prata em 3
    autor = users(:ana)

    Emblema.avaliar!(autor)
    vinculo = pensador.emblema_usuarios.find_by(user: autor)
    assert_nil vinculo, "sem ideia aprovada não entra"

    3.times { |i| Ideia.create!(autor: autor, titulo: "Ideia #{i}", tipo: "projeto", status: "aprovada") }
    Emblema.avaliar!(autor)

    vinculo = pensador.emblema_usuarios.find_by(user: autor)
    assert_equal "Prata", vinculo.nivel.nome
    assert_equal 1, vinculo.conquistas_count, "métrica gera UM registro de entrada, não um por degrau"
  end

  test "reavaliar de novo não duplica registro nem re-notifica" do
    autor = users(:ana)
    Ideia.create!(autor: autor, titulo: "Ideia", tipo: "projeto", status: "aprovada")

    Emblema.avaliar!(autor)
    vinculo = emblemas(:pensador).emblema_usuarios.find_by(user: autor)
    assert_no_difference -> { vinculo.conquistas.count } do
      3.times { Emblema.avaliar!(autor) }
    end
  end

  # ------------------------------------------------------------ Teto de donos

  test "teto de donos fecha o emblema depois do enésimo" do
    pioneiro = emblemas(:comprador_pioneiro) # limite_donos: 2

    assert pioneiro.conceder!(users(:ana), origem: "concessao")
    assert pioneiro.conceder!(users(:diretor), origem: "concessao")
    assert pioneiro.reload.lotado?
    assert_nil pioneiro.conceder!(users(:membro_user), origem: "concessao"),
               "o terceiro não entra"
    assert_equal 2, pioneiro.reload.usuarios_count
  end

  test "quem já tem continua registrando mesmo com o teto atingido" do
    escalonavel = emblemas(:maratonista)
    escalonavel.update!(limite_donos: 1)
    escalonavel.conceder!(users(:diretor), origem: "concessao", descricao: "A")

    # ana já tinha o emblema pelas fixtures: o teto barra dono NOVO, não registro
    assert emblemas(:maratonista).conceder!(users(:ana), origem: "concessao", descricao: "B")
    assert_equal 3, emblema_usuarios(:ana_maratonista).reload.conquistas_count
  end

  # ----------------------------------------------------------------- Discord

  test "subir de rank troca o cargo: sai o antigo, entra o novo" do
    maratonista = emblemas(:maratonista)
    # bronze tem cargo nas fixtures; prata não
    cargo_bronze = emblema_niveis(:maratonista_bronze).discord_role_id

    assert_enqueued_with job: DiscordCargoJob, args: [ users(:diretor).id, cargo_bronze, "adicionar" ] do
      maratonista.conceder!(users(:diretor), origem: "concessao")
    end

    assert_enqueued_with job: DiscordCargoJob, args: [ users(:diretor).id, cargo_bronze, "remover" ] do
      maratonista.conceder!(users(:diretor), origem: "concessao")
    end
  end

  # -------------------------------------------------------------- Raridade

  test "o nível conhece o próprio percentual — a raridade do rank" do
    com_total_de_usuarios(100) do
      # só ana está no prata do maratonista
      assert_equal 1.0, emblema_niveis(:maratonista_prata).percentual
      assert_equal 0.0, emblema_niveis(:maratonista_ouro).percentual
    end
  end

  # -------------------------------------------------------------- Validação

  test "escalonável recusa meta — o limiar mora em cada rank" do
    emblema = emblemas(:maratonista)

    assert_not emblema.update(meta: 5)
    assert_includes emblema.errors[:meta].to_sentence, "escalonável"
  end

  test "dois ranks não podem dividir o mesmo limiar no mesmo emblema" do
    duplicado = EmblemaNivel.new(emblema: emblemas(:maratonista), rank: emblema_ranks(:elite), limiar: 2)

    assert_not duplicado.valid?
  end

  private

  def com_total_de_usuarios(total)
    original = Emblema.method(:total_usuarios)
    Emblema.define_singleton_method(:total_usuarios) { total }
    yield
  ensure
    Emblema.define_singleton_method(:total_usuarios, original)
  end
end
