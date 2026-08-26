ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# O dotenv roda em :development E :test (ver Gemfile), então as credenciais
# REAIS do .env chegam aqui. Sem isto, qualquer teste que passe por uma tela de
# Discord faz chamada de verdade à API — lento, instável, e capaz de criar ou
# APAGAR cargo no servidor da liga a partir de uma suíte de teste.
#
# Quem precisa fingir que está configurado atribui as duas no próprio setup.
ENV["DISCORD_BOT_TOKEN"] = nil
ENV["DISCORD_GUILD_ID"] = nil
ENV["DISCORD_WEBHOOK_URL"] = nil

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers.
    # Processos (não threads): threads disputam a conexão do Postgres com
    # fixtures transacionais e quebram com "owned by a different thread".
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
