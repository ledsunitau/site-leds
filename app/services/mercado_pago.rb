require "net/http"

# Gateway de pagamento (RF-LOJ-12/RN-12) via Checkout Pro do Mercado Pago.
# Guardamos SÓ a referência externa da cobrança — nunca dado de cartão (o cartão
# é digitado no site do MP). O access token vem do ENV; sem ele, configurado? é
# false e o checkout responde "pagamento indisponível".
#
# Fonte da verdade é a API, não o corpo do webhook: consultar_pagamento relê o
# pagamento no MP, então um webhook forjado só consegue disparar uma consulta de
# um id que não é nosso (o token escopa à nossa conta) e é ignorado.
module MercadoPago
  API = "https://api.mercadopago.com".freeze

  class ErroGateway < StandardError; end

  module_function

  def configurado? = ENV["MERCADO_PAGO_ACCESS_TOKEN"].present?

  # Cria a preferência de checkout do pedido; devolve { id:, init_point: }.
  # init_point é a URL para onde o cliente é redirecionado para pagar.
  def criar_preferencia(pedido)
    corpo = {
      items: pedido.itens.map do |item|
        {
          title: item.produto.nome,
          quantity: item.quantidade,
          unit_price: item.preco_unitario.to_f,
          currency_id: "BRL"
        }
      end,
      external_reference: pedido.id.to_s, # o webhook devolve isto → acha o pedido
      notification_url: url("/pagamentos/webhook"),
      back_urls: { success: url("/loja/pedidos/#{pedido.id}"), pending: url("/loja/pedidos/#{pedido.id}"),
                   failure: url("/loja/pedidos/#{pedido.id}") }
    }
    resposta = requisitar(Net::HTTP::Post, "/checkout/preferences", corpo)
    { id: resposta["id"], init_point: resposta["init_point"] }
  end

  # Relê um pagamento no gateway (id vindo do webhook). Devolve status, valor e
  # o external_reference (id do pedido).
  def consultar_pagamento(payment_id)
    requisitar(Net::HTTP::Get, "/v1/payments/#{payment_id}")
  end

  # MP → nosso enum de pagamentos.
  def self.traduzir_status(mp_status)
    case mp_status
    when "approved" then "aprovado"
    when "rejected", "cancelled" then "recusado"
    when "refunded", "charged_back" then "estornado"
    else "pendente"
    end
  end

  def self.requisitar(klasse, caminho, corpo = nil)
    raise ErroGateway, "Mercado Pago não configurado" unless configurado?

    req = klasse.new(URI("#{API}#{caminho}"))
    req["Authorization"] = "Bearer #{ENV['MERCADO_PAGO_ACCESS_TOKEN']}"
    req["Content-Type"] = "application/json"
    req.body = corpo.to_json if corpo

    resposta = Net::HTTP.start("api.mercadopago.com", 443, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
      http.request(req)
    end
    raise ErroGateway, "MP respondeu #{resposta.code}" unless resposta.is_a?(Net::HTTPSuccess)

    JSON.parse(resposta.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
    # sem timeout, um gateway travado penduraria o worker/conexão indefinidamente
    raise ErroGateway, "Falha de rede com o Mercado Pago (#{e.class})"
  end
  private_class_method :requisitar

  # URL absoluta para o MP (notification_url/back_urls). Sem APP_HOST, ERRA em vez
  # de mandar um host chutado: uma notification_url errada faria o webhook nunca
  # chegar e o pedido ficar preso em aguardando_pagamento.
  def self.url(caminho)
    host = ENV["APP_HOST"].presence or raise ErroGateway, "APP_HOST não configurado"
    "https://#{host}#{caminho}"
  end
  private_class_method :url
end
