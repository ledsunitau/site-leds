# Tentativa de pagamento (RN-12/RF-LOJ-12). Guarda SÓ o gateway e a referência
# externa da cobrança — NUNCA dado de cartão. Vários por pedido (tentativas que
# falham e refazem). O aprovado é quem confirma a compra (Pedido#marcar_pago!).
class Pagamento < ApplicationRecord
  belongs_to :pedido

  STATUSES = %w[pendente aprovado recusado estornado].freeze
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :gateway, presence: true
  validates :valor, numericality: { greater_than_or_equal_to: 0 }
end
