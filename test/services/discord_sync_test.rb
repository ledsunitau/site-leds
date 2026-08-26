require "test_helper"

# Sincronização de cargos com o Discord. A garantia mais importante aqui não é
# "cria o cargo certo" — é **nunca tocar em cargo que não é nosso**. O servidor
# tem cargos de moderação, de bots e feitos à mão; um bug aqui apaga cargo de
# gente real e não dá para desfazer.
class DiscordSyncTest < ActiveSupport::TestCase
  # cargo do servidor que o site NÃO criou — o intruso que nunca pode ser tocado
  MODERACAO = { "id" => "111111111111111111", "name" => "Moderação", "color" => 16711680 }.freeze

  setup do
    @token = ENV["DISCORD_BOT_TOKEN"]
    @guild = ENV["DISCORD_GUILD_ID"]
    ENV["DISCORD_BOT_TOKEN"] = "bot-token"
    ENV["DISCORD_GUILD_ID"] = "123456789"
  end

  teardown do
    ENV["DISCORD_BOT_TOKEN"] = @token
    ENV["DISCORD_GUILD_ID"] = @guild
  end

  # ------------------------------------------------------------ Configuração

  test "sem token ou sem guild não faz request nenhum" do
    ENV["DISCORD_BOT_TOKEN"] = nil
    assert_not DiscordSync.configurado?
    com_cargos_no_servidor([]) { assert_raises(DiscordSync::NaoConfigurado) { DiscordSync.plano } }
    assert_empty @chamadas

    ENV["DISCORD_BOT_TOKEN"] = "bot-token"
    ENV["DISCORD_GUILD_ID"] = nil
    com_cargos_no_servidor([]) { assert_raises(DiscordSync::NaoConfigurado) { DiscordSync.plano } }
    assert_empty @chamadas
  end

  # ------------------------------------------------------------------- Plano

  test "classifica criar, atualizar e apagar" do
    plano = com_cargos_no_servidor([ MODERACAO, cargo_veterano ]) { DiscordSync.plano }

    # maratonista está marcado e não tem role_id → criar
    assert_includes plano[:criar].map(&:nome), "Maratonista"
    # veterano existe no servidor com nome igual e cor igual → nada a fazer
    assert_empty plano[:atualizar].map(&:nome)
    # o órfão das fixtures não é reivindicado por ninguém → apagar
    assert_equal [ "900000000000000009" ], plano[:apagar].map(&:role_id)
  end

  test "nome ou cor divergente entra em atualizar" do
    fora_de_sincronia = cargo_veterano.merge("name" => "Nome antigo")
    plano = com_cargos_no_servidor([ fora_de_sincronia ]) { DiscordSync.plano }

    assert_includes plano[:atualizar].map(&:nome), "Veterano"
  end

  test "marcado com id que sumiu do servidor volta para criar" do
    # o gestor apagou o cargo à mão lá: o id existe no site mas não na guild
    plano = com_cargos_no_servidor([ MODERACAO ]) { DiscordSync.plano }

    assert_includes plano[:criar].map(&:nome), "Veterano"
  end

  # ESTA é a garantia central.
  test "cargo do servidor fora de discord_cargos NUNCA entra em apagar" do
    plano = com_cargos_no_servidor([ MODERACAO, cargo_veterano ]) { DiscordSync.plano }

    assert_not_includes plano[:apagar].map(&:role_id), MODERACAO["id"],
                        "cargo que o site não criou jamais pode ser proposto para exclusão"
  end

  test "desmarcar um item transforma o cargo dele em órfão" do
    emblemas(:veterano).update!(discord_sincronizar: false)
    plano = com_cargos_no_servidor([ cargo_veterano ]) { DiscordSync.plano }

    assert_includes plano[:apagar].map(&:role_id), "900000000000000001"
  end

  # ----------------------------------------------------------------- Aplicar

  test "criar guarda o id no registro e passa a gerenciar o cargo" do
    novo = { "id" => "555000555000555000", "name" => "Maratonista", "color" => 1934069 }

    com_cargos_no_servidor([], criar: novo) { DiscordSync.aplicar!(apagar: false) }

    assert_equal "555000555000555000", emblemas(:maratonista).reload.discord_role_id
    assert DiscordCargo.exists?(role_id: "555000555000555000")
    assert_includes @chamadas.map { |c| c[:verbo] }, Net::HTTP::Post
  end

  test "aplicar sem confirmar NÃO apaga" do
    com_cargos_no_servidor([ cargo_veterano ]) { DiscordSync.aplicar!(apagar: false) }

    assert_not_includes @chamadas.map { |c| c[:verbo] }, Net::HTTP::Delete
    assert DiscordCargo.exists?(role_id: "900000000000000009"), "o órfão continua registrado"
  end

  test "aplicar com apagar remove o órfão e o registro" do
    com_cargos_no_servidor([ cargo_veterano ]) { DiscordSync.aplicar!(apagar: true) }

    assert_not DiscordCargo.exists?(role_id: "900000000000000009")
  end

  test "cargo já apagado à mão (404) some do registro em vez de travar o diff" do
    com_cargos_no_servidor([ cargo_veterano ], status_delete: 404) do
      DiscordSync.aplicar!(apagar: true)
    end

    assert_not DiscordCargo.exists?(role_id: "900000000000000009")
  end

  # ------------------------------------------------------------------ Membro

  test "sincronizar_membro adiciona o que falta e remove o que a pessoa perdeu" do
    ana = users(:ana)
    # ana NÃO tem o veterano no site, mas tem o cargo dele no Discord
    com_membro([ "900000000000000001", MODERACAO["id"] ]) { DiscordSync.sincronizar_membro!(ana) }

    escritas = @chamadas.reject { |c| c[:verbo] == Net::HTTP::Get }
    assert_equal [ Net::HTTP::Delete ], escritas.map { |c| c[:verbo] }.uniq
    assert(escritas.all? { |c| c[:url].include?("900000000000000001") },
           "só o cargo nosso pode ser removido")
  end

  test "sincronizar_membro não encosta em cargo que o site não gerencia" do
    com_membro([ MODERACAO["id"] ]) { DiscordSync.sincronizar_membro!(users(:ana)) }

    assert_equal 1, @chamadas.size, "só a leitura do membro; nada a escrever"
    assert_not(@chamadas.any? { |c| c[:url].include?(MODERACAO["id"]) })
  end

  test "sem Discord vinculado, recusa antes de qualquer request" do
    com_membro([]) do
      assert_raises(DiscordSync::NaoConfigurado) { DiscordSync.sincronizar_membro!(users(:membro_user)) }
    end

    assert_empty @chamadas
  end

  test "cargos devidos juntam emblema, rank e elo" do
    ana = users(:ana)
    emblemas(:maratonista).update!(discord_role_id: "700000000000000001")
    emblema_niveis(:maratonista_prata).update!(discord_role_id: "700000000000000002")
    elos(:prata_elo).update!(discord_role_id: "700000000000000003")
    ana.update_columns(elo_id: elos(:prata_elo).id)

    devidos = DiscordSync.new.cargos_devidos(ana.reload)

    assert_includes devidos, "700000000000000001"
    assert_includes devidos, "700000000000000002"
    assert_includes devidos, "700000000000000003"
  end

  private

  def cargo_veterano
    { "id" => "900000000000000001", "name" => "Veterano",
      "color" => emblemas(:veterano).cor.delete("#").to_i(16) }
  end

  # Duplo do Net::HTTP: devolve a lista de cargos no GET da guild, o cargo novo
  # no POST, e registra tudo que foi chamado.
  #
  # A regra vai como ARGUMENTO, não como bloco: o bloco de `responder` é a ação
  # sob teste, e Ruby não aceita &bloco junto de um bloco literal na mesma chamada.
  def com_cargos_no_servidor(cargos, criar: nil, status_delete: 204, &acao)
    regra = lambda do |verbo, url|
      if verbo == Net::HTTP::Get && url.end_with?("/roles") then [ 200, cargos.to_json ]
      elsif verbo == Net::HTTP::Post then [ 201, (criar || {}).to_json ]
      elsif verbo == Net::HTTP::Delete then [ status_delete, "" ]
      else [ 204, "" ]
      end
    end
    responder(regra, &acao)
  end

  def com_membro(roles, &acao)
    regra = lambda do |verbo, url|
      if verbo == Net::HTTP::Get && url.include?("/members/")
        [ 200, { "roles" => roles }.to_json ]
      else
        [ 204, "" ]
      end
    end
    responder(regra, &acao)
  end

  # Troca Net::HTTP.start na mão — mesma técnica do discord_webhook_job_test.
  # Devolve o VALOR do bloco (o plano, o resultado do aplicar!); o que foi
  # chamado fica em @chamadas, para os testes que olham as requisições.
  def responder(regra)
    @chamadas = chamadas = []
    original = Net::HTTP.method(:start)
    duplo = Object.new
    duplo.define_singleton_method(:request) do |req|
      chamadas << { verbo: req.class, url: req.uri.to_s, corpo: req.body }
      codigo, corpo = regra.call(req.class, req.uri.to_s)
      resposta = Net::HTTPResponse::CODE_TO_OBJ.fetch(codigo.to_s).new("1.1", codigo.to_s, "")
      # @read: sem isso o #body tentaria ler do socket, que não existe aqui
      resposta.instance_variable_set(:@body, corpo)
      resposta.instance_variable_set(:@read, true)
      resposta
    end
    Net::HTTP.define_singleton_method(:start) { |*_a, **_k, &b| b.call(duplo) }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
