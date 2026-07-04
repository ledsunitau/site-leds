require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "exige login" do
    get profile_path
    assert_redirected_to new_user_session_path
  end

  test "mostra o perfil com contas vinculadas" do
    sign_in users(:ana)
    get profile_path

    body = response.parsed_body
    assert_equal "Ana Comunidade", body["name"]
    assert_equal "comunidade", body["role"]
    assert_equal [ { "id" => oauth_identities(:ana_discord).id,
                     "provider" => "discord",
                     "username" => "aninha" } ], body["contas_vinculadas"]
  end

  test "atualiza o nome" do
    sign_in users(:ana)
    patch profile_path, params: { user: { name: "Ana Atualizada" } }

    assert_response :success
    assert_equal "Ana Atualizada", users(:ana).reload.name
  end

  test "rejeita nome vazio" do
    sign_in users(:ana)
    patch profile_path, params: { user: { name: "" } }

    assert_response :unprocessable_entity
  end

  test "desvincular conta externa remove só a identidade do próprio usuário" do
    sign_in users(:diretor)
    assert_no_difference "OauthIdentity.count" do
      delete oauth_identity_path(oauth_identities(:ana_discord))
    end
    assert_response :not_found

    sign_in users(:ana)
    assert_difference "OauthIdentity.count", -1 do
      delete oauth_identity_path(oauth_identities(:ana_discord))
    end
    assert_redirected_to profile_path
  end
end
