require "test_helper"

# RF-NOT: centro in-app, preferências, inscrições push, e o disparo pelo fluxo
# de moderação de posts.
class NotificationsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "notifications exige login" do
    get notifications_path
    assert_response :redirect
  end

  test "index lista as notificações do usuário e conta as não lidas; read marca" do
    PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver([ users(:ana) ])
    sign_in users(:ana)

    get notifications_path
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["nao_lidas"]
    notif = body["notificacoes"].first
    assert_equal "PostSubmetidoNotifier", notif["tipo"]
    assert_not notif["lida"]

    post read_notification_path(notif["id"])
    assert_response :no_content
    assert users(:ana).notifications.find(notif["id"]).read?

    get notifications_path
    assert_equal 0, response.parsed_body["nao_lidas"]
  end

  test "read_all zera as não lidas" do
    PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver([ users(:ana) ])
    sign_in users(:ana)

    post read_all_notifications_path
    assert_response :no_content
    assert_equal 0, users(:ana).notifications.unread.count
  end

  test "só o dono vê/marca suas notificações" do
    PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver([ users(:ana) ])
    alheia = users(:ana).notifications.first

    sign_in users(:diretor)
    post read_notification_path(alheia)
    assert_response :not_found
    assert_not alheia.reload.read?
  end

  test "preferências: upsert por canal/categoria (RF-NOT-06)" do
    sign_in users(:ana)

    post notification_preferences_path, params: { canal: "email", categoria: "moderacao", enabled: "false" }
    assert_response :created
    assert_not response.parsed_body["enabled"]

    # mesmo canal/categoria: atualiza a linha, não cria outra
    assert_no_difference "NotificationPreference.count" do
      post notification_preferences_path, params: { canal: "email", categoria: "moderacao", enabled: "true" }
    end
    assert NotificationPreference.find_by(user: users(:ana), canal: "email", categoria: "moderacao").enabled

    get notification_preferences_path
    assert_equal 1, response.parsed_body["preferencias"].size
  end

  test "canal inválido na preferência é 422" do
    sign_in users(:ana)
    post notification_preferences_path, params: { canal: "sms", categoria: "moderacao", enabled: "true" }
    assert_response :unprocessable_entity
  end

  test "categoria fora da lista fechada é 422 (não cria linha ilimitada)" do
    sign_in users(:ana)
    assert_no_difference "NotificationPreference.count" do
      post notification_preferences_path, params: { canal: "email", categoria: "inexistente", enabled: "true" }
    end
    assert_response :unprocessable_entity
  end

  test "canal não-configurável (in_app) é 422 — não aceita preferência morta" do
    sign_in users(:ana)
    post notification_preferences_path, params: { canal: "in_app", categoria: "moderacao", enabled: "false" }
    assert_response :unprocessable_entity
  end

  test "enabled vazio (checkbox limpo) vira true, não 500" do
    sign_in users(:ana)
    post notification_preferences_path, params: { canal: "email", categoria: "moderacao", enabled: "" }
    assert_response :created
    assert response.parsed_body["enabled"]
  end

  test "push: cria por endpoint (upsert), expõe chave pública e remove" do
    sign_in users(:ana)

    get vapid_public_key_push_subscriptions_path
    assert_response :success
    assert response.parsed_body["public_key"].present?

    assert_difference "PushSubscription.count", 1 do
      post push_subscriptions_path, params: { push_subscription: { endpoint: "https://p/1", p256dh: "k", auth: "a" } }
    end
    id = response.parsed_body["id"]

    # mesmo endpoint: atualiza, não duplica
    assert_no_difference "PushSubscription.count" do
      post push_subscriptions_path, params: { push_subscription: { endpoint: "https://p/1", p256dh: "k2", auth: "a2" } }
    end

    delete push_subscription_path(id)
    assert_response :no_content
    assert_not PushSubscription.exists?(id)
  end

  test "push: reinscrever o mesmo endpoint por outro usuário reatribui (navegador compartilhado)" do
    users(:diretor).push_subscriptions.create!(endpoint: "https://p/shared", p256dh: "k", auth: "a")

    sign_in users(:ana)
    assert_no_difference "PushSubscription.count" do
      post push_subscriptions_path, params: { push_subscription: { endpoint: "https://p/shared", p256dh: "k2", auth: "a2" } }
    end
    assert_response :created
    assert_equal users(:ana).id, PushSubscription.find_by(endpoint: "https://p/shared").user_id
  end

  test "wiring: submeter avisa a gestão; aprovar avisa o autor" do
    post_alvo = posts(:rascunho_do_membro) # autor: membro_user (não é gestão)

    sign_in users(:membro_user)
    post submeter_post_path(post_alvo)
    assert_response :success
    gestor_notif = users(:diretor).notifications.joins(:event)
                                  .where(noticed_events: { type: "PostSubmetidoNotifier" })
    assert gestor_notif.exists?, "gestão foi notificada da submissão"
    assert_not users(:membro_user).notifications.joins(:event)
                                  .where(noticed_events: { type: "PostSubmetidoNotifier" }).exists?,
               "o próprio autor não se notifica"

    sign_in users(:diretor)
    post aprovar_post_path(post_alvo)
    assert_response :success
    autor_notif = users(:membro_user).notifications.joins(:event)
                                     .where(noticed_events: { type: "PostModeradoNotifier" })
    assert autor_notif.exists?, "autor foi notificado da aprovação"
  end
end
