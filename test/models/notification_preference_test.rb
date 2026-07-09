require "test_helper"

class NotificationPreferenceTest < ActiveSupport::TestCase
  test "opt-out: sem linha explícita o canal está habilitado (RF-NOT-06)" do
    assert NotificationPreference.habilitado?(user: users(:ana), canal: :email, categoria: "moderacao")
  end

  test "linha com enabled=false desabilita o canal para aquela categoria" do
    NotificationPreference.create!(user: users(:ana), canal: "email", categoria: "moderacao", enabled: false)

    assert_not NotificationPreference.habilitado?(user: users(:ana), canal: :email, categoria: "moderacao")
    assert NotificationPreference.habilitado?(user: users(:ana), canal: :push, categoria: "moderacao"),
           "só o canal desabilitado é afetado"
    assert NotificationPreference.habilitado?(user: users(:ana), canal: :email, categoria: "publicacao"),
           "só a categoria desabilitada é afetada"
  end

  test "canal fora do CHECK é inválido (422 via enum validate, não 500)" do
    pref = NotificationPreference.new(user: users(:ana), canal: "sms", categoria: "x")
    assert_not pref.valid?
  end

  test "único por usuário+canal+categoria" do
    NotificationPreference.create!(user: users(:ana), canal: "email", categoria: "moderacao")
    duplicada = NotificationPreference.new(user: users(:ana), canal: "email", categoria: "moderacao")
    assert_not duplicada.valid?
  end
end
