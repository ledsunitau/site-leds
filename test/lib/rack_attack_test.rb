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

  private

  def normalize(path)
    Rack::Attack.normalized_path(Struct.new(:path).new(path))
  end
end
