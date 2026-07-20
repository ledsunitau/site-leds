# Checkout de estoque (RF-LOJ-04): fecha o carrinho num pedido e devolve a URL de
# pagamento do gateway. entrega escolhe retirada (padrão) ou envio (frete cotado
# no servidor, RF-LOJ-11). Do próprio usuário logado (escopo = autz, RN-17).
class CheckoutController < ApplicationController
  before_action :authenticate_user!

  def create
    pedido = Checkout.do_carrinho(current_user, entrega: entrega_params)
    init_point = Pagamentos.iniciar(pedido)

    render json: { pedido: pedido.card_json, pagamento_url: init_point }, status: :created
  rescue Checkout::Erro => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  rescue MercadoPago::ErroGateway, MelhorEnvio::ErroFrete
    # o pedido pode já existir (aguardando_pagamento) — retomável em /pedidos/:id/pagar
    render json: { errors: [ "Serviço indisponível no momento. Tente novamente." ] },
           status: :service_unavailable
  end

  private

  def entrega_params
    entrega = params[:entrega]
    return {} unless entrega.respond_to?(:permit) # ausente ou escalar → retirada

    entrega.permit(:tipo_entrega, :endereco_id, :servico_id).to_h.symbolize_keys
  end
end
