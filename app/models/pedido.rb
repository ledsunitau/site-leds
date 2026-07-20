# Pedido da loja (RF-LOJ-04). Nasce em aguardando_pagamento a partir do
# carrinho (estoque) ou da conversão de uma reserva (sob demanda). O pagamento
# aprovado no gateway o leva a 'pago' (RF-LOJ-07/12). O total é congelado na
# criação; os itens guardam o preço pago (snapshot). Auditado (RN-13).
#
# ADIADO (branch do frete): tipo_entrega 'envio' + frete + rastreamento
# (transportadora/servico_frete/frete_valor/melhor_envio_ref/rastreamento_codigo)
# e as transições de fulfillment (em_producao → enviado → entregue). Aqui só
# retirada e o par aguardando_pagamento → pago / cancelado.
class Pedido < ApplicationRecord
  has_paper_trail

  belongs_to :comprador, class_name: "User", foreign_key: :user_id,
                         optional: true, inverse_of: :pedidos
  belongs_to :endereco, optional: true
  has_many :itens, class_name: "ItemPedido", dependent: :destroy
  has_many :pagamentos, dependent: :destroy
  has_one :reserva, dependent: :nullify # a reserva convertida aponta pra cá
  # é record de notifier (PedidoPagoNotifier) — limpa os eventos se for destruído
  has_many :noticed_events, as: :record, dependent: :destroy,
                            class_name: "Noticed::Event", inverse_of: :record

  TIPOS_ENTREGA = %w[retirada envio].freeze
  STATUSES = %w[aguardando_pagamento pago em_producao enviado entregue cancelado].freeze
  enum :tipo_entrega, TIPOS_ENTREGA.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo (marcar_pago!/cancelar!)
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :total, numericality: { greater_than_or_equal_to: 0 }
  validate :envio_exige_endereco

  scope :em_aberto, -> { aguardando_pagamento }

  # pagamento aprovado → avisa o comprador (RF-LOJ-04); e, se for ENVIO, compra a
  # etiqueta em background (RF-LOJ-11). Enviado/entregue avisam o comprador.
  after_update_commit :notificar_pago, if: -> { saved_change_to_status? && pago? }
  after_update_commit :agendar_etiqueta, if: -> { saved_change_to_status? && pago? && envio? }
  after_update_commit :notificar_enviado, if: -> { saved_change_to_status? && enviado? }
  after_update_commit :notificar_entregue, if: -> { saved_change_to_status? && entregue? }

  # Pagamento aprovado confirma a compra (RF-LOJ-07): aguardando_pagamento → pago.
  # Sob demanda: a reserva vira 'convertida'. Idempotente e travado (transicionar!):
  # dois webhooks do mesmo pagamento não pagam duas vezes.
  def marcar_pago!
    transicionar!("pago", de: %w[aguardando_pagamento]) { reserva&.marcar_convertida! }
  end

  # Cancelável enquanto não pago (o cliente desiste). Devolve o estoque reservado.
  def cancelar!
    transicionar!("cancelado", de: %w[aguardando_pagamento]) { itens.each(&:devolver_estoque!) }
  end

  # Fulfillment (RF-LOJ-04, tracking). em_producao é manual (gestão prepara);
  # enviado vem da etiqueta (EtiquetaJob) ou de envio manual da gestão; entregue
  # vem do rastreio (RastreioUpdateJob) ou de confirmação manual da gestão.
  def marcar_em_producao!
    transicionar!("em_producao", de: %w[pago])
  end

  def marcar_enviado!(codigo, ref: nil)
    transicionar!("enviado", de: %w[pago em_producao]) do
      self.rastreamento_codigo = codigo
      self.melhor_envio_ref = ref if ref
    end
  end

  def marcar_entregue!
    transicionar!("entregue", de: %w[enviado])
  end

  def card_json
    {
      id: id,
      status: status,
      tipo_entrega: tipo_entrega,
      total: total,
      frete_valor: frete_valor,
      transportadora: transportadora,
      servico_frete: servico_frete,
      prazo_estimado: prazo_estimado,
      rastreamento_codigo: rastreamento_codigo,
      endereco: endereco&.card_json,
      itens: itens.map(&:card_json),
      criado_em: created_at
    }
  end

  private

  # Transição de status idempotente e travada: no-op se já no destino, erra se a
  # origem não permite. O bloco ajusta campos extras (código de rastreio etc.).
  def transicionar!(destino, de:)
    with_lock do
      return if status == destino
      unless de.include?(status)
        errors.add(:status, "transição inválida de #{status} para #{destino}")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      yield if block_given?
      update!(status: destino)
    end
  end

  def envio_exige_endereco
    errors.add(:endereco, "é obrigatório para envio") if envio? && endereco_id.nil?
  end

  def notificar_pago
    PedidoPagoNotifier.with(record: self).deliver(comprador) if comprador
  end

  def agendar_etiqueta
    EtiquetaJob.perform_later(id)
  end

  def notificar_enviado
    PedidoEnviadoNotifier.with(record: self).deliver(comprador) if comprador
  end

  def notificar_entregue
    PedidoEntregueNotifier.with(record: self).deliver(comprador) if comprador
  end
end
