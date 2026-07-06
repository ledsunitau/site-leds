require "net/http"

# RF-NOV-11: anuncia no canal do Discord quando um post é publicado
# (disparado pelo after_commit do Post). Sem bot persistente — um POST
# simples no webhook do canal, via Solid Queue.
class DiscordWebhookJob < ApplicationJob
  queue_as :default

  # 4xx (menos 429) é permanente — webhook revogado/URL errada nunca vai
  # passar; repetir só ocuparia a fila. Só o TRANSIENTE recua e tenta de
  # novo: timeout (Net::*Timeout < RuntimeError), rede (SystemCallError,
  # SocketError) e o nosso raise de 429/5xx (RuntimeError). Erro de código
  # (NoMethodError etc.) falha alto de primeira, sem retry.
  # As classes são disjuntas de ErroPermanente — o discard nunca é
  # sombreado pelo retry (handlers casam do último declarado para trás).
  class ErroPermanente < StandardError; end
  retry_on RuntimeError, SystemCallError, SocketError,
           wait: :polynomially_longer, attempts: 5
  discard_on ErroPermanente

  def perform(post_id)
    url = ENV["DISCORD_WEBHOOK_URL"]
    return if url.blank?

    post = Post.find_by(id: post_id)
    return unless post&.publicado? # despublicado entre a fila e a execução

    resposta = Net::HTTP.post(URI(url), payload(post).to_json,
                              "Content-Type" => "application/json")
    case resposta
    when Net::HTTPSuccess then nil
    when Net::HTTPTooManyRequests
      raise "Webhook do Discord respondeu 429"
    when Net::HTTPClientError
      raise ErroPermanente, "Webhook do Discord respondeu #{resposta.code}"
    else
      raise "Webhook do Discord respondeu #{resposta.code}"
    end
  end

  private

  def payload(post)
    chamada = post.noticia? ? "Notícia nova no site da LEDS" : "Post novo no blog da LEDS"
    embed = { title: post.titulo, description: post.caller || post.subtitulo }.compact
    # APP_HOST é o host público que os mailers já usam (production.rb)
    embed[:url] = "https://#{ENV["APP_HOST"]}/posts/#{post.id}" if ENV["APP_HOST"].present?

    { content: "📰 #{chamada}: #{post.titulo}", embeds: [ embed ] }
  end
end
