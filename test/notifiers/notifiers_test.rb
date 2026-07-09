require "test_helper"

class NotifiersTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  test "deliver grava uma notificação in-app por destinatário" do
    destinatarios = [ users(:ana), users(:diretor) ]

    assert_difference "Noticed::Notification.count", 2 do
      PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver(destinatarios)
    end
    assert users(:ana).notifications.exists?
    assert_equal "\"Rascunho de notícia\" entrou na fila de aprovação.",
                 users(:ana).notifications.last.event.mensagem
  end

  test "apagar o post limpa as notificações (sem órfãs → sem 500 no centro)" do
    PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver([ users(:ana) ])
    assert users(:ana).notifications.exists?

    assert_difference "Noticed::Notification.count", -1 do
      posts(:rascunho_do_membro).destroy
    end
    assert_not users(:ana).notifications.exists?
  end

  test "notifier tolera record nil (post apagado entre evento e leitura)" do
    evento = PostSubmetidoNotifier.new(record: nil)
    assert_nothing_raised { evento.mensagem }
  end

  test "e-mail respeita a preferência por canal/categoria (RF-NOT-06)" do
    NotificationPreference.create!(user: users(:diretor), canal: "email", categoria: "moderacao", enabled: false)

    perform_enqueued_jobs do
      PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver([ users(:ana), users(:diretor) ])
    end

    destinos = ActionMailer::Base.deliveries.flat_map(&:to)
    assert_includes destinos, users(:ana).email, "ana não desabilitou → recebe"
    assert_not_includes destinos, users(:diretor).email, "diretor desabilitou moderacao/email"
  end

  test "web push: apaga expirada, tolera transiente e não aborta os demais subs" do
    users(:ana).push_subscriptions.create!(endpoint: "https://push/ok", p256dh: "k1", auth: "a1")
    users(:ana).push_subscriptions.create!(endpoint: "https://push/morta", p256dh: "k2", auth: "a2")
    users(:ana).push_subscriptions.create!(endpoint: "https://push/instavel", p256dh: "k3", auth: "a3")

    enviados = []
    stub_web_push(->(endpoint:, **) {
      resp = Struct.new(:code, :body).new("410", "")
      raise WebPush::ExpiredSubscription.new(resp, "host") if endpoint.include?("morta")
      raise WebPush::PushServiceError.new(resp, "host") if endpoint.include?("instavel")
      enviados << endpoint
    }) do
      perform_enqueued_jobs do
        PostSubmetidoNotifier.with(record: posts(:rascunho_do_membro)).deliver([ users(:ana) ])
      end
    end

    assert_equal [ "https://push/ok" ], enviados, "o sub ok recebe apesar do expirado e do transiente"
    assert_not PushSubscription.exists?(endpoint: "https://push/morta"), "expirada foi limpa"
    assert PushSubscription.exists?(endpoint: "https://push/instavel"), "transiente é mantida (best-effort)"
  end

  test "discord DM pula sem bot token; posta quando há token e uid" do
    # sem token: nenhuma chamada HTTP
    chamadas = []
    stub_net_post(->(*args) { chamadas << args; resposta_json("{}") }) do
      perform_enqueued_jobs do
        PostModeradoNotifier.with(record: posts(:blog_publicado), resultado: "publicado").deliver(users(:ana))
      end
    end
    assert_empty chamadas, "sem DISCORD_BOT_TOKEN não chama a API"

    # com token + ana tem discord (fixture ana_discord uid 111222333)
    with_env("DISCORD_BOT_TOKEN", "bot-abc") do
      chamadas = []
      stub_net_post(->(uri, *_) { chamadas << uri.to_s; resposta_json('{"id":"canal1"}') }) do
        perform_enqueued_jobs do
          PostModeradoNotifier.with(record: posts(:blog_publicado), resultado: "publicado").deliver(users(:ana))
        end
      end
      assert_includes chamadas, "https://discord.com/api/v10/users/@me/channels"
      assert_includes chamadas, "https://discord.com/api/v10/channels/canal1/messages"
    end
  end

  private

  def stub_web_push(fake)
    original = WebPush.method(:payload_send)
    WebPush.define_singleton_method(:payload_send) { |**kwargs| fake.call(**kwargs) }
    yield
  ensure
    WebPush.define_singleton_method(:payload_send, original)
  end

  def stub_net_post(fake)
    original = Net::HTTP.method(:post)
    Net::HTTP.define_singleton_method(:post) { |*args| fake.call(*args) }
    yield
  ensure
    Net::HTTP.define_singleton_method(:post, original)
  end

  def resposta_json(body)
    r = Net::HTTPOK.new("1.1", "200", "OK")
    r.instance_variable_set(:@read, true)
    r.define_singleton_method(:body) { body }
    r
  end

  def with_env(chave, valor)
    antigo = ENV[chave]
    ENV[chave] = valor
    yield
  ensure
    ENV[chave] = antigo
  end
end
