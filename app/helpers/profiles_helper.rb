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

  # Etapas do rastreador. Retirada pula "enviado" (não há transporte), então
  # mostra 4 etapas contra as 5 do envio — é o esperado, não falta nada.
  #
  # A exceção é o pedido de retirada que JÁ está enviado (marcado por engano
  # antes de Pedido#marcar_enviado! passar a recusar): a etapa aparece assim
  # mesmo, senão o rastreador esconderia o estado real do registro.
  def pedido_etapas(pedido)
    etapas = %w[aguardando_pagamento pago em_producao]
    etapas += %w[enviado] if pedido.tipo_entrega == "envio" || pedido.status == "enviado"
    etapas + %w[entregue]
  end

  # Índice da etapa atual (para preencher o stepper). -1 se cancelado.
  def pedido_etapa_atual(pedido)
    return -1 if pedido.status == "cancelado"

    # sem o fallback explícito, um status fora da lista viraria índice 0 e o
    # rastreador diria que o pedido voltou para o começo
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
