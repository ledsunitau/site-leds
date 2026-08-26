require "net/http"

# Chamadas à API do Discord: monta a requisição e classifica a resposta.
#
# SÓ REST. A política de retry mora em DiscordRest::PoliticaDeJob, separada de
# propósito: `retry_on`/`discard_on` são macros de ActiveJob, e um service PORO
# que incluísse esta concern estouraria NoMethodError no carregamento da classe.
# Jobs incluem as duas; services, só esta.
#
# 4xx (menos 429) é permanente — webhook revogado, DM bloqueada, cargo apagado à
# mão: repetir só ocupa a fila. Só o TRANSIENTE recua: timeout (Net::*Timeout <
# RuntimeError), rede (SystemCallError, SocketError) e o raise de 429/5xx
# (RuntimeError). As classes são disjuntas de ErroPermanente — o discard nunca é
# sombreado pelo retry (handlers casam do último declarado para trás).
module DiscordRest
  extend ActiveSupport::Concern

  class ErroPermanente < StandardError; end

  API = "https://discord.com/api/v10".freeze

  # Retry/discard de ActiveJob. Separado porque só faz sentido dentro de um job.
  module PoliticaDeJob
    extend ActiveSupport::Concern

    included do
      retry_on RuntimeError, SystemCallError, SocketError,
               wait: :polynomially_longer, attempts: 5
      discard_on DiscordRest::ErroPermanente
    end
  end

  private

  def post_discord(url, corpo, headers = {})
    classificar Net::HTTP.post(URI(url), corpo.to_json,
                               { "Content-Type" => "application/json" }.merge(headers))
  end

  # Verbo explícito: cargo usa PUT/DELETE sem corpo, criar/editar cargo usa
  # POST/PATCH com corpo, e listar usa GET. Mesmo tratamento de resposta para
  # todos — a política de retry é da API, não do verbo.
  def chamar_discord(verbo, url, headers = {}, corpo = nil)
    uri = URI(url)
    cabecalhos = { "Content-Type" => "application/json" }.merge(headers)
    requisicao = verbo.new(uri, cabecalhos)
    requisicao.body = corpo.to_json if corpo

    resposta = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(requisicao)
    end

    classificar resposta
  end

  # Corpo JSON da resposta, ou nil quando não há (204 No Content é o normal em
  # PUT/DELETE de cargo).
  def json_discord(resposta)
    corpo = resposta.body
    JSON.parse(corpo) if corpo.present?
  rescue JSON::ParserError
    nil
  end

  def auth_discord(token) = { "Authorization" => "Bot #{token}" }

  def classificar(resposta)
    case resposta
    when Net::HTTPSuccess then resposta
    when Net::HTTPTooManyRequests then raise "Discord respondeu 429"
    when Net::HTTPClientError then raise ErroPermanente, "Discord respondeu #{resposta.code}"
    else raise "Discord respondeu #{resposta.code}"
    end
  end
end
