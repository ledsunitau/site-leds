require "test_helper"

class OmniauthFlowTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-1",
      info: { email: "nova@example.com", name: "Nova Pessoa" }
    )
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord",
      uid: "discord-uid-1",
      info: { email: "diretor@example.com", name: "dario_dev" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.mock_auth[:discord] = nil
  end

  test "login Google cria usuário novo com identidade normalizada" do
    assert_difference [ "User.count", "OauthIdentity.count" ], 1 do
      post user_google_oauth2_omniauth_authorize_path
      follow_redirect!
    end

    user = User.find_by!(email: "nova@example.com")
    assert_equal "Nova Pessoa", user.name
    assert_equal "comunidade", user.role
    identity = user.oauth_identities.sole
    assert_equal "google", identity.provider # normalizado do "google_oauth2"
  end

  test "login OAuth com e-mail já cadastrado vincula à conta existente" do
    assert_no_difference "User.count" do
      assert_difference "OauthIdentity.count", 1 do
        post user_discord_omniauth_authorize_path
        follow_redirect!
      end
    end

    identity = users(:diretor).oauth_identities.sole
    assert_equal "discord", identity.provider
    assert_equal "dario_dev", identity.username
  end

  test "usuário logado vincula Discord ao próprio perfil" do
    OmniAuth.config.mock_auth[:discord][:uid] = "discord-uid-2"
    OmniAuth.config.mock_auth[:discord][:info][:email] = nil # vínculo não depende de e-mail

    sign_in users(:diretor)
    post user_discord_omniauth_authorize_path
    follow_redirect!

    assert_redirected_to profile_path
    assert_equal "dario_dev", users(:diretor).reload.discord_username
  end

  test "identidade de outro usuário não pode ser vinculada" do
    OmniAuth.config.mock_auth[:discord][:uid] = "111222333" # já é da ana (fixture)

    sign_in users(:diretor)
    assert_no_difference "OauthIdentity.count" do
      post user_discord_omniauth_authorize_path
      follow_redirect!
    end

    assert_equal users(:ana).id, OauthIdentity.find_by(uid: "111222333").user_id
  end

  test "login repetido atualiza o username armazenado" do
    users(:ana).update!(email: "ana-discord@example.com")
    OmniAuth.config.mock_auth[:discord][:uid] = "111222333"
    OmniAuth.config.mock_auth[:discord][:info][:name] = "aninha_nova"

    post user_discord_omniauth_authorize_path
    follow_redirect!

    assert_equal "aninha_nova", oauth_identities(:ana_discord).reload.username
  end
end
