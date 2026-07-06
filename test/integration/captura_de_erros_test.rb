require "test_helper"

# RNF-14/RN-16: exceção não tratada vira error_log com params mascarados.
class CapturaDeErrosTest < ActionDispatch::IntegrationTest
  # Controller descartável só deste teste (resolvido pelo nome da rota).
  class QuebradoController < ApplicationController
    def show
      raise "explosão controlada"
    end
  end

  class JobQueQuebra < ApplicationJob
    def perform(_senha, _post_id)
      raise "quebrou de propósito"
    end
  end

  test "500 em request vira error_log com rota, usuário e payload MASCARADO" do
    com_rota_quebrada do
      sign_in users(:membro_user)

      assert_difference "ErrorLog.count", 1 do
        assert_raises(RuntimeError) do
          post "/quebrado", params: { titulo: "ok", password: "supersecreta" }
        end
      end
    end

    log = ErrorLog.order(:id).last
    assert_equal "RuntimeError", log.error_class
    assert_equal "explosão controlada", log.error_message
    assert_equal "POST /quebrado", log.rota
    assert_equal "show", log.acao_tentada
    assert_equal users(:membro_user).id, log.user_id
    assert_equal "ok", log.input_payload["titulo"]
    assert_equal "[FILTERED]", log.input_payload["password"], "RN-16: senha nunca em claro"
    assert_equal "error", log.severidade
    assert log.backtrace.present?
  end

  test "404 (RecordNotFound) não vira error_log — é fluxo normal de API" do
    assert_no_difference "ErrorLog.count" do
      get acao_path(999_999)
    end
    assert_response :not_found
  end

  test "falha em job vira error_log com argumentos POSICIONAIS mascarados" do
    assert_difference "ErrorLog.count", 1 do
      assert_raises(RuntimeError) { JobQueQuebra.perform_now("senha-em-claro", 42) }
    end

    log = ErrorLog.order(:id).last
    assert_equal "CapturaDeErrosTest::JobQueQuebra", log.componente
    assert_equal "RuntimeError", log.error_class
    assert_nil log.user_id
    # RN-16: string posicional pode ser segredo — sempre mascarada; id fica
    assert_equal [ "[FILTERED]", 42 ], log.input_payload["arguments"]
    assert_equal 1, log.input_payload["tentativa"]
  end

  test "?pagina gigante não vira 500 nem error_log (clamp do offset)" do
    assert_no_difference "ErrorLog.count" do
      get posts_path(pagina: "99999999999999999999")
    end
    assert_response :success
    assert_equal [], response.parsed_body["posts"]
  end

  private

  # Redesenha as rotas SÓ dentro do bloco — os outros testes usam as reais.
  def com_rota_quebrada
    Rails.application.routes.draw do
      devise_for :users
      post "quebrado", to: "captura_de_erros_test/quebrado#show"
    end
    yield
  ensure
    Rails.application.reload_routes!
  end
end
