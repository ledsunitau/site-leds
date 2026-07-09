require "net/http"

# POST na API do Discord com política de retry compartilhada entre quem bate
# nela: o webhook de canal (DiscordWebhookJob) e o DM por bot (DeliveryMethods::
# DiscordDm). Um só lugar para a classificação de resposta e o retry, senão os
# dois divergem numa mudança da API.
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
    resposta = Net::HTTP.post(URI(url), corpo.to_json,
                              { "Content-Type" => "application/json" }.merge(headers))
    case resposta
    when Net::HTTPSuccess then resposta
    when Net::HTTPTooManyRequests then raise "Discord respondeu 429"
    when Net::HTTPClientError then raise ErroPermanente, "Discord respondeu #{resposta.code}"
    else raise "Discord respondeu #{resposta.code}"
    end
  end
end
