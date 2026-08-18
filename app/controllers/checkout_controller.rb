# Checkout de estoque (RF-LOJ-04): fecha o carrinho num pedido. O que acontece
# depois depende do modo de pagamento da loja (Setting):
#   direto       → "intenção de compra": avisa a gestão, que fecha por contato
#                  (sem Mercado Pago ainda). É o padrão de hoje.
#   mercado_pago → devolve a URL de pagamento do gateway (fluxo já pronto para
#                  quando houver credenciais).
# entrega escolhe retirada (padrão) ou envio (adiado — retirada-only por ora).
# Do próprio usuário logado (escopo = autz, RN-17).
class CheckoutController < ApplicationController
  before_action :authenticate_user!
  before_action :loja_aberta!

  def create
    pedido = Checkout.do_carrinho(current_user, entrega: entrega_params)
    # trunca (não valida-e-falha): o pedido já existe aqui, um contato longo não
    # pode deixá-lo órfão. O cap de verdade é o length no model (defesa em profundidade).
    contato = params[:contato].to_s.strip.truncate(120).presence
    pedido.update!(contato: contato) if contato

    if Setting.modo_pagamento == "mercado_pago"
      finalizar_com_gateway(pedido)
    else
      finalizar_intencao(pedido)
    end
  rescue Checkout::Erro => e
    responder_erro([ e.message ], :unprocessable_entity, volta: carrinho_path)
  rescue MercadoPago::ErroGateway, MelhorEnvio::ErroFrete
    # o pedido pode já existir (aguardando_pagamento) — retomável em /pedidos/:id/pagar
    responder_erro([ "Serviço indisponível no momento. Tente novamente." ],
                   :service_unavailable, volta: carrinho_path)
  end

  private

  # Modo direto: pedido registrado como intenção; a gestão é avisada e fecha por
  # contato. Mercado Pago NÃO é chamado.
  def finalizar_intencao(pedido)
    gestores = User.gestao.to_a
    IntencaoCompraNotifier.with(record: pedido).deliver(gestores) if gestores.any?

    respond_to do |format|
      format.html do
        redirect_to produtos_path,
                    notice: "Pedido registrado! A gestão vai entrar em contato para combinar o pagamento e a retirada. 🛍️"
      end
      format.json { render json: { pedido: pedido.card_json, modo: "direto" }, status: :created }
    end
  end

  def finalizar_com_gateway(pedido)
    init_point = Pagamentos.iniciar(pedido)

    respond_to do |format|
      format.html { redirect_to init_point, allow_other_host: true }
      format.json { render json: { pedido: pedido.card_json, pagamento_url: init_point }, status: :created }
    end
  end

  def responder_erro(mensagens, status, volta:)
    respond_to do |format|
      format.html { redirect_to volta, alert: mensagens.to_sentence }
      format.json { render json: { errors: mensagens }, status: status }
    end
  end

  # Loja desligada pela gestão: ninguém finaliza compra (nem staff — a loja está
  # fechada para vendas).
  def loja_aberta!
    return if Setting.loja_ativa?

    responder_erro([ "Loja indisponível no momento." ], :service_unavailable, volta: produtos_path)
  end

  def entrega_params
    entrega = params[:entrega]
    return {} unless entrega.respond_to?(:permit) # ausente ou escalar → retirada

    entrega.permit(:tipo_entrega, :endereco_id, :servico_id).to_h.symbolize_keys
  end
end
