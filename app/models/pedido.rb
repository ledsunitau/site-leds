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

  # pagamento aprovado → avisa o comprador (RF-LOJ-04)
  after_update_commit :notificar_pago, if: -> { saved_change_to_status? && pago? }

  # Pagamento aprovado confirma a compra (RF-LOJ-07). with_lock: dois webhooks
  # do mesmo pagamento (o gateway reenvia) não devem pagar duas vezes nem
  # reprocessar. Idempotente: se já pago, não faz nada.
  def marcar_pago!
    with_lock do
      return if pago?
      unless aguardando_pagamento?
        errors.add(:status, "só pedido aguardando pagamento vira pago")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      update!(status: "pago")
      reserva&.marcar_convertida! # sob demanda: a reserva vira 'convertida'
    end
  end

  # Cancelável enquanto não pago (o cliente desiste antes de pagar). Devolve o
  # estoque reservado no checkout de estoque.
  def cancelar!
    with_lock do
      unless aguardando_pagamento?
        errors.add(:status, "só pedido aguardando pagamento pode ser cancelado")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      itens.each { |item| item.devolver_estoque! }
      update!(status: "cancelado")
    end
  end

  def card_json
    {
      id: id,
      status: status,
      tipo_entrega: tipo_entrega,
      total: total,
      itens: itens.map(&:card_json),
      criado_em: created_at
    }
  end

  private

  def envio_exige_endereco
    errors.add(:endereco, "é obrigatório para envio") if envio? && endereco_id.nil?
  end

  def notificar_pago
    PedidoPagoNotifier.with(record: self).deliver(comprador) if comprador
  end
end
