require "net/http"

# RF-NOV-11: anuncia no canal do Discord quando um post é publicado
# (disparado pelo after_commit do Post). Sem bot persistente — um POST
# simples no webhook do canal, via Solid Queue.
class DiscordWebhookJob < ApplicationJob
  include DiscordRest # ErroPermanente + retry/discard + post_discord

  queue_as :default

  def perform(post_id)
    url = ENV["DISCORD_WEBHOOK_URL"]
    return if url.blank?

    post = Post.find_by(id: post_id)
    return unless post&.publicado? # despublicado entre a fila e a execução

    post_discord(url, payload(post))
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
