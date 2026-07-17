# Reserva do modo sob demanda (RF-LOJ-05/06, RN-10): sem pagamento, sem
# validade, cancelável. Só produto sob_demanda e ativo pode ser reservado
# (regra de negócio na aplicação, modelagem C9).
#
# PENDENTE (branch do checkout/pagamento): RF-LOJ-05/07 — quando as reservas
# ATIVAS de um produto atingem produto.quantidade_alvo, um JOB avisa os
# reservantes para pagar; quem paga tem a reserva CONVERTIDA num pedido
# (pedido_id preenchido). O disparo e a conversão vivem lá porque dependem de
# pedidos/pagamentos. Aqui só existem os estados e a criação/cancelamento.
class Reserva < ApplicationRecord
  include VarianteCoerente # variante tem de existir e ser DESTE produto

  belongs_to :user
  belongs_to :produto
  belongs_to :variante, optional: true

  STATUSES = %w[ativa cancelada convertida].freeze
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo (cancelar!); a conversão chega no checkout
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :quantidade, numericality: { greater_than: 0 }
  validate :produto_reservável, on: :create
  # uma reserva ATIVA por (usuário, produto, variante): reservar de novo é
  # ajustar quantidade, não empilhar linha (bounda o abuso e a demanda inflada).
  # App-level (o DDL não declara único) — janela de corrida vira duplicata, não dano.
  validate :sem_reserva_ativa_duplicada, on: :create

  # RF-LOJ-06/RN-10: cancelável enquanto ativa (antes do disparo). O registro
  # fica (soft), vira 'cancelada' — histórico de demanda se preserva. with_lock
  # relê a linha: sem ele, cancelar! e a conversão (checkout) passariam ambos no
  # guard lido em memória e o cancelamento sobrescreveria uma reserva convertida.
  def cancelar!
    with_lock do
      unless ativa?
        errors.add(:status, "só reserva ativa pode ser cancelada")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      update!(status: "cancelada")
    end
  end

  def card_json
    {
      id: id,
      status: status,
      quantidade: quantidade,
      variante: variante&.card_json,
      produto: produto.card_json,
      criada_em: created_at
    }
  end

  private

  def produto_reservável
    return if produto.nil?

    errors.add(:produto, "não está disponível") unless produto.ativo?
    errors.add(:produto, "não é sob demanda — não se reserva") unless produto.sob_demanda?
  end

  def sem_reserva_ativa_duplicada
    return unless ativa?

    duplicada = Reserva.ativa.where(user_id:, produto_id:, variante_id:).exists?
    errors.add(:base, "Você já tem uma reserva ativa deste produto.") if duplicada
  end
end
