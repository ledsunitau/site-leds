# Ponte entre o pedido e o gateway. iniciar cria a preferência e devolve a URL
# de pagamento; confirmar_por_webhook processa a notificação do MP.
module Pagamentos
  module_function

  # Devolve o init_point (URL de pagamento) para redirecionar o cliente.
  def iniciar(pedido)
    raise MercadoPago::ErroGateway, "Pedido não está aguardando pagamento." unless pedido.aguardando_pagamento?

    MercadoPago.criar_preferencia(pedido).fetch(:init_point)
  end

  # Webhook do MP (topic=payment). NÃO confia no corpo: relê o pagamento no
  # gateway. Idempotente — o MP reenvia a notificação, então find_or_initialize
  # pelo id do pagamento e marcar_pago! não repaga.
  #
  # SÓ confirma se o valor pago BATE com o total (defesa contra subpagamento: um
  # aprovado de R$1 não pode quitar um pedido de R$100). Recusado só é
  # registrado — o cliente pode tentar de novo (RF-LOJ-12: várias tentativas);
  # o estoque retido é liberado pelo ExpirarPedidosJob, não a cada recusa.
  # ADIADO (branch de refund): estornado é registrado mas não reverte o pedido.
  def confirmar_por_webhook(payment_id)
    dados = MercadoPago.consultar_pagamento(payment_id)
    pedido = Pedido.find_by(id: dados["external_reference"])
    return if pedido.nil?

    valor = dados["transaction_amount"]
    pagamento = pedido.pagamentos.find_or_initialize_by(gateway: "mercado_pago", gateway_ref: payment_id.to_s)
    pagamento.update!(status: MercadoPago.traduzir_status(dados["status"]), valor: valor || 0)

    if pagamento.aprovado? && pedido.aguardando_pagamento?
      if valor && BigDecimal(valor.to_s) >= pedido.total
        pedido.marcar_pago!
      else
        # aprovado mas o valor não fecha: não confirma — a gestão decide
        Rails.logger.warn("Pagamento #{payment_id}: valor #{valor} < total #{pedido.total} do pedido #{pedido.id}")
      end
    end
    pagamento
  end
end
