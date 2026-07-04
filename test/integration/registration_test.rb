require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  # Regressão: o sanitizer do Devise descartava o name (NOT NULL) e nenhum
  # cadastro por e-mail/senha funcionava (RF-AUT-01).
  test "cadastro por e-mail/senha cria usuário com nome e role comunidade" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: {
        user: {
          name: "Novo Usuário",
          email: "novo@example.com",
          password: "senha-segura-123",
          password_confirmation: "senha-segura-123"
        }
      }
    end

    user = User.find_by!(email: "novo@example.com")
    assert_equal "Novo Usuário", user.name
    assert_equal "comunidade", user.role
  end

  test "cadastro sem nome é rejeitado" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          email: "sem-nome@example.com",
          password: "senha-segura-123",
          password_confirmation: "senha-segura-123"
        }
      }
    end
    assert_response :unprocessable_entity
  end
end
