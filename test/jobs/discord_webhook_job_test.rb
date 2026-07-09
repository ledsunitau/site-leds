require "test_helper"

class DiscordWebhookJobTest < ActiveJob::TestCase
  setup do
    @url_antiga = ENV["DISCORD_WEBHOOK_URL"]
    ENV["DISCORD_WEBHOOK_URL"] = "https://discord.com/api/webhooks/1/token"
  end

  teardown do
    ENV["DISCORD_WEBHOOK_URL"] = @url_antiga
  end

  test "posta o anúncio no webhook com título e chamada do post" do
    chamadas = []
    fake = ->(uri, body, headers) { chamadas << [ uri.to_s, JSON.parse(body), headers ]; resposta_ok }

    com_post_falso(fake) do
      DiscordWebhookJob.perform_now(posts(:noticia_publicada).id)
    end

    uri, corpo, headers = chamadas.first
    assert_equal ENV["DISCORD_WEBHOOK_URL"], uri
    assert_equal "application/json", headers["Content-Type"]
    assert_match posts(:noticia_publicada).titulo, corpo["content"]
    embed = corpo["embeds"].first
    assert_equal posts(:noticia_publicada).titulo, embed["title"]
    assert_equal posts(:noticia_publicada).caller, embed["description"]
  end

  test "sem webhook configurado, não chama o Discord" do
    ENV["DISCORD_WEBHOOK_URL"] = nil

    chamadas = 0
    com_post_falso(->(*) { chamadas += 1; resposta_ok }) do
      DiscordWebhookJob.perform_now(posts(:noticia_publicada).id)
    end

    assert_equal 0, chamadas
  end

  test "post despublicado ou apagado entre a fila e a execução é ignorado" do
    chamadas = 0
    com_post_falso(->(*) { chamadas += 1; resposta_ok }) do
      DiscordWebhookJob.perform_now(posts(:rascunho_do_membro).id)
      DiscordWebhookJob.perform_now(-1)
    end

    assert_equal 0, chamadas
  end

  test "fim a fim: 404 descarta o job de vez (sem retry); 429 agenda retry" do
    revogado = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    com_post_falso(->(*) { revogado }) do
      assert_no_enqueued_jobs only: DiscordWebhookJob do
        DiscordWebhookJob.perform_now(posts(:noticia_publicada).id)
      end
    end

    rate_limit = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
    com_post_falso(->(*) { rate_limit }) do
      assert_enqueued_with job: DiscordWebhookJob do
        DiscordWebhookJob.perform_now(posts(:noticia_publicada).id)
      end
    end
  end

  test "429 levanta erro comum (vai para retry); 404 levanta erro permanente (descartado)" do
    rate_limit = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
    com_post_falso(->(*) { rate_limit }) do
      assert_raises(RuntimeError) do
        DiscordWebhookJob.new.perform(posts(:noticia_publicada).id)
      end
    end

    revogado = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    com_post_falso(->(*) { revogado }) do
      assert_raises(DiscordRest::ErroPermanente) do
        DiscordWebhookJob.new.perform(posts(:noticia_publicada).id)
      end
    end
  end

  private

  # minitest 6 não traz mais o stub embutido: troca Net::HTTP.post na mão.
  def com_post_falso(fake)
    original = Net::HTTP.method(:post)
    Net::HTTP.define_singleton_method(:post) { |*args| fake.call(*args) }
    yield
  ensure
    Net::HTTP.define_singleton_method(:post, original)
  end

  def resposta_ok
    Net::HTTPNoContent.new("1.1", "204", "No Content")
  end
end
