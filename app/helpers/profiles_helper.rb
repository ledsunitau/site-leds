module ProfilesHelper
  # ---- Pedidos (Loja) ----
  PEDIDO_STATUS_LABEL = {
    "aguardando_pagamento" => "Aguardando pagamento", "pago" => "Pago",
    "em_producao" => "Em produção", "enviado" => "Enviado",
    "entregue" => "Entregue", "cancelado" => "Cancelado"
  }.freeze

  # Pedido ativo (em andamento) vs concluído (terminal).
  ATIVOS = %w[aguardando_pagamento pago em_producao enviado].freeze

  def pedido_ativo?(pedido) = ATIVOS.include?(pedido.status)

  def pedido_status_label(status) = PEDIDO_STATUS_LABEL[status] || status.to_s.humanize

  # Etapas do rastreador. Retirada pula "enviado" (não há transporte).
  def pedido_etapas(pedido)
    base = %w[aguardando_pagamento pago em_producao]
    base + (pedido.tipo_entrega == "envio" ? %w[enviado entregue] : %w[entregue])
  end

  # Índice da etapa atual (para preencher o stepper). -1 se cancelado.
  def pedido_etapa_atual(pedido)
    return -1 if pedido.status == "cancelado"
    pedido_etapas(pedido).index(pedido.status) || 0
  end

  # ---- Novidades: badge de status do post ----
  POST_STATUS = {
    "rascunho" => [ "Rascunho", "cinza" ], "em_aprovacao" => [ "Em aprovação", "amarelo" ],
    "publicado" => [ "Publicado", "verde" ], "rejeitado" => [ "Rejeitado", "vermelho" ]
  }.freeze

  def post_status_label(status) = (POST_STATUS[status] || [ status.to_s.humanize, "cinza" ]).first
  def post_status_cor(status)   = (POST_STATUS[status] || [ nil, "cinza" ]).last

  # ---- Dinheiro (R$ 1.234,56) ----
  def moeda(valor)
    return "—" if valor.nil?
    "R$ " + format("%.2f", valor).tr(".", ",")
  end
end
