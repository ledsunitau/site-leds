require "test_helper"

# O job recebe o ROLE_ID direto (não o emblema): emblema, rank e elo dão cargo,
# e "sai o cargo do prata, entra o do ouro" não caberia num id de emblema.
class DiscordCargoJobTest < ActiveJob::TestCase
  CARGO = "999888777666555444".freeze

  setup do
    @token_antigo = ENV["DISCORD_BOT_TOKEN"]
    @guild_antiga = ENV["DISCORD_GUILD_ID"]
    ENV["DISCORD_BOT_TOKEN"] = "bot-token"
    ENV["DISCORD_GUILD_ID"] = "123456789"
  end

  teardown do
    ENV["DISCORD_BOT_TOKEN"] = @token_antigo
    ENV["DISCORD_GUILD_ID"] = @guild_antiga
  end

  # ana tem oauth_identity de discord na fixture
  test "adiciona o cargo com PUT na rota da guild" do
    chamadas = capturar { rodar("adicionar") }

    verbo, uri, headers = chamadas.first
    assert_equal Net::HTTP::Put, verbo
    assert_equal "https://discord.com/api/v10/guilds/123456789/members/" \
                 "#{oauth_identities(:ana_discord).uid}/roles/#{CARGO}", uri
    assert_equal "Bot bot-token", headers["Authorization"]
  end

  test "remover usa DELETE na mesma rota" do
    assert_equal Net::HTTP::Delete, capturar { rodar("remover") }.first.first
  end

  test "pula em silêncio sem bot token, sem guild, sem cargo ou sem Discord vinculado" do
    ENV["DISCORD_BOT_TOKEN"] = nil
    assert_equal 0, capturar { rodar("adicionar") }.size

    ENV["DISCORD_BOT_TOKEN"] = "bot-token"
    ENV["DISCORD_GUILD_ID"] = nil
    assert_equal 0, capturar { rodar("adicionar") }.size

    ENV["DISCORD_GUILD_ID"] = "123456789"
    # emblema/rank/elo sem cargo configurado: o job recebe nil e não faz nada
    assert_equal 0, capturar {
      DiscordCargoJob.perform_now(users(:ana).id, nil, "adicionar")
    }.size

    # usuário sem conta do Discord vinculada
    assert_equal 0, capturar {
      DiscordCargoJob.perform_now(users(:membro_user).id, CARGO, "adicionar")
    }.size
  end

  test "ação desconhecida levanta em vez de adivinhar o verbo" do
    assert_raises(KeyError) do
      DiscordCargoJob.new.perform(users(:ana).id, CARGO, "sei_la")
    end
  end

  private

  def rodar(acao)
    DiscordCargoJob.perform_now(users(:ana).id, CARGO, acao)
  end

  # Troca Net::HTTP.start na mão (mesma técnica do discord_webhook_job_test):
  # o duplo de http registra a requisição e devolve 204.
  def capturar
    chamadas = []
    original = Net::HTTP.method(:start)
    duplo = Object.new
    duplo.define_singleton_method(:request) do |requisicao|
      chamadas << [ requisicao.class, requisicao.uri.to_s, requisicao ]
      Net::HTTPNoContent.new("1.1", "204", "No Content")
    end
    Net::HTTP.define_singleton_method(:start) { |*_args, **_kw, &bloco| bloco.call(duplo) }
    yield
    chamadas
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
