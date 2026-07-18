# Checkout de estoque (RF-LOJ-04): fecha o carrinho num pedido e devolve a URL
# de pagamento do gateway. Só retirada aqui — envio/frete chega na branch do
# frete. Do próprio usuário logado (escopo = autz, RN-17).
class CheckoutController < ApplicationController
  before_action :authenticate_user!

  def create
    pedido = Checkout.do_carrinho(current_user)
    init_point = Pagamentos.iniciar(pedido)

    render json: { pedido: pedido.card_json, pagamento_url: init_point }, status: :created
  rescue Checkout::Erro => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  rescue MercadoPago::ErroGateway
    # o pedido já existe (aguardando_pagamento) — o cliente reinicia em /pedidos/:id/pagar
    render json: { errors: [ "Pagamento indisponível no momento. Tente novamente." ] },
           status: :service_unavailable
  end
end
