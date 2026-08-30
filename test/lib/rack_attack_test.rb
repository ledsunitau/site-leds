require "test_helper"

class RackAttackTest < ActiveSupport::TestCase
  # Regressão: comparação exata de req.path deixava POST /users/password.json
  # passar por fora de todos os throttles (RNF-15).
  test "normalized_path remove sufixo de formato e barra final" do
    assert_equal "/users/password", normalize("/users/password.json")
    assert_equal "/users/sign_in", normalize("/users/sign_in/")
    assert_equal "/users", normalize("/users.json")
    assert_equal "/users", normalize("/users")
  end

  # A regra do cabeçalho do initializer: endpoint público de escrita novo entra
  # com throttle na mesma PR. POST /posts virou público na tela de escrita de
  # escritores/jornalistas (RF-NOV-04) e não tinha nenhum.
  test "POST /posts é throttled; GET /posts não" do
    throttle = Rack::Attack.throttles["posts/ip"]
    assert throttle, "criar novidade precisa de throttle"

    assert_equal "10.0.0.1", throttle.block.call(req("POST", "/posts"))
    assert_nil throttle.block.call(req("GET", "/posts")), "ler novidade não é escrita"
    assert_nil throttle.block.call(req("POST", "/posts/1/comentarios")), "comentário tem throttle próprio"
  end

  private

  def req(metodo, caminho)
    Struct.new(:path, :request_method, :ip) do
      def post? = request_method == "POST"
    end.new(caminho, metodo, "10.0.0.1")
  end

  def normalize(path)
    Rack::Attack.normalized_path(Struct.new(:path).new(path))
  end
end
