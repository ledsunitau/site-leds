require "test_helper"

class OauthIdentityTest < ActiveSupport::TestCase
  test "normaliza google_oauth2 para google (nome do DDL)" do
    assert_equal "google", OauthIdentity.normalize_provider("google_oauth2")
    assert_equal "discord", OauthIdentity.normalize_provider("discord")
  end

  test "uid é único por provider" do
    duplicate = OauthIdentity.new(user: users(:diretor), provider: "discord", uid: "111222333")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:uid, :taken)
  end

  test "provider fora do DDL é inválido" do
    identity = OauthIdentity.new(user: users(:ana), provider: "github", uid: "999")
    assert_not identity.valid?
  end
end
