require "net/http"

# Chamadas à API do Discord com política de retry compartilhada entre quem bate
# nela: o webhook de canal (DiscordWebhookJob), o DM por bot (DeliveryMethods::
# DiscordDm) e os cargos de emblema (DiscordCargoJob). Um só lugar para a
# classificação de resposta e o retry, senão os três divergem numa mudança da API.
#
# 4xx (menos 429) é permanente — webhook revogado/DM bloqueada nunca vai passar,
# repetir só ocupa a fila. Só o TRANSIENTE recua: timeout (Net::*Timeout <
# RuntimeError), rede (SystemCallError, SocketError) e o raise de 429/5xx
# (RuntimeError). As classes são disjuntas de ErroPermanente — o discard nunca é
# sombreado pelo retry (handlers casam do último declarado para trás).
module DiscordRest
  extend ActiveSupport::Concern

  class ErroPermanente < StandardError; end

  included do
    retry_on RuntimeError, SystemCallError, SocketError,
             wait: :polynomially_longer, attempts: 5
    discard_on ErroPermanente
  end

  private

  def post_discord(url, corpo, headers = {})
    classificar Net::HTTP.post(URI(url), corpo.to_json,
                               { "Content-Type" => "application/json" }.merge(headers))
  end

  # Cargo de emblema usa PUT/DELETE sem corpo (RF-EMB). Verbo próprio em vez de
  # generalizar post_discord: a política de retry é da API, não do verbo, então
  # o que os dois compartilham é só `classificar`.
  def chamar_discord(verbo, url, headers = {})
    uri = URI(url)
    resposta = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(verbo.new(uri, headers))
    end

    classificar resposta
  end

  def classificar(resposta)
    case resposta
    when Net::HTTPSuccess then resposta
    when Net::HTTPTooManyRequests then raise "Discord respondeu 429"
    when Net::HTTPClientError then raise ErroPermanente, "Discord respondeu #{resposta.code}"
    else raise "Discord respondeu #{resposta.code}"
    end
  end
end
