# DM no Discord via bot token REST (RF-NOT-04). Abre o canal privado com o
# usuário (POST /users/@me/channels) e posta a mensagem. Sem bot token ou sem
# Discord vinculado ao usuário, pula. Retry/classificação de resposta vêm da
# concern DiscordRest (mesma política do webhook de canal).
module DeliveryMethods
  class DiscordDm < ApplicationDeliveryMethod
    include DiscordRest

    API = "https://discord.com/api/v10".freeze

    def deliver
      token = ENV["DISCORD_BOT_TOKEN"]
      uid = recipient.discord_uid
      return if token.blank? || uid.blank?

      canal_id = abrir_dm(token, uid)
      return if canal_id.blank? # 2xx sem "id" (shape inesperada) — não posta em /channels//messages

      enviar_mensagem(token, canal_id)
    end

    private

    def abrir_dm(token, uid)
      resposta = post_discord("#{API}/users/@me/channels", { recipient_id: uid }, auth(token))
      JSON.parse(resposta.body)["id"]
    end

    def enviar_mensagem(token, canal_id)
      texto = "**#{event.titulo}**\n#{event.mensagem}"
      texto += "\n#{event.link_absoluto}" if event.link_absoluto
      post_discord("#{API}/channels/#{canal_id}/messages", { content: texto }, auth(token))
    end

    def auth(token)
      { "Authorization" => "Bot #{token}" }
    end
  end
end
