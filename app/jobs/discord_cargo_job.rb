require "net/http"

# RF-EMB: sincroniza cargos do Discord com o que a pessoa conquistou. Três
# coisas dão cargo — o emblema em si, o rank alcançado nele e o elo do usuário —
# então o job recebe o ROLE_ID direto em vez de olhar o emblema: subir de rank é
# "remove o cargo do prata, adiciona o do ouro", que não cabe num id de emblema.
#
# Pula em silêncio quando falta qualquer peça — sem bot token, sem guild
# configurada ou sem Discord vinculado. Mesma postura do DeliveryMethods::
# DiscordDm: emblema no site funciona com ou sem Discord.
class DiscordCargoJob < ApplicationJob
  include DiscordRest # ErroPermanente + retry/discard + chamar_discord

  queue_as :default

  API = "https://discord.com/api/v10".freeze
  VERBOS = { "adicionar" => Net::HTTP::Put, "remover" => Net::HTTP::Delete }.freeze

  def perform(user_id, role_id, acao)
    verbo = VERBOS.fetch(acao)
    token = ENV["DISCORD_BOT_TOKEN"]
    guild = ENV["DISCORD_GUILD_ID"]
    return if token.blank? || guild.blank? || role_id.blank?

    uid = User.find_by(id: user_id)&.discord_uid
    return if uid.blank?

    chamar_discord(verbo, "#{API}/guilds/#{guild}/members/#{uid}/roles/#{role_id}",
                   "Authorization" => "Bot #{token}")
  end
end
