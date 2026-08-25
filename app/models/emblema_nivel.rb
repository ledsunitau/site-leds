# O degrau de um emblema escalonável: "neste emblema, o rank Ouro começa em 4".
#
# Nível ≠ rank: o RANK é o nome/cor global (Ouro); o NÍVEL é onde esse rank
# entra NESTE emblema. Por isso o limiar mora aqui e a aparência mora no rank.
class EmblemaNivel < ApplicationRecord
  belongs_to :emblema
  belongs_to :rank, class_name: "EmblemaRank", inverse_of: :niveis
  has_many :emblema_usuarios, foreign_key: :nivel_id, dependent: :nullify, inverse_of: :nivel

  validates :limiar, numericality: { only_integer: true, greater_than: 0 }
  validates :rank_id, uniqueness: { scope: :emblema_id }
  validates :limiar, uniqueness: { scope: :emblema_id }

  # do maior limiar para o menor: o primeiro que couber no progresso é o rank
  scope :do_maior, -> { order(limiar: :desc) }
  scope :ordenados, -> { order(:limiar) }

  delegate :nome, :cor, :efeito, :peso, to: :rank

  # Quantos usuários pararam exatamente neste nível — a raridade do rank
  # ("Ouro — só 3,1% dos usuários").
  def percentual
    total = Emblema.total_usuarios
    return 0.0 if total.zero?

    (emblema_usuarios.count * 100.0 / total).round(1)
  end
end
