# Catálogo global de ranks (RF-EMB): Bronze, Prata, Ouro, Esmeralda, Diamante,
# Elite. Criado UMA vez pela gestão e reusado por todo emblema escalonável —
# mudar a cor do ouro muda em todos, e "Ouro" não sai de tom diferente em cada.
#
# O rank não tem ícone próprio: o desenho é do emblema, o rank dá a cor e o
# efeito. É assim que se lê "o mesmo maratonista, agora em ouro".
class EmblemaRank < ApplicationRecord
  has_paper_trail

  # restrict no banco: rank em uso por algum emblema não some do catálogo
  has_many :niveis, class_name: "EmblemaNivel", foreign_key: :rank_id,
                    dependent: :restrict_with_error, inverse_of: :rank

  validates :nome, presence: true, uniqueness: true
  validates :cor, format: { with: /\A#\h{6}\z/, message: "deve ser um hexadecimal como #CD7F32" }
  validates :efeito, inclusion: { in: Emblema::EFEITOS }
  # peso é o multiplicador dos pontos do elo (bronze 1, ouro 6…)
  validates :peso, numericality: { only_integer: true, greater_than: 0 }
  validates :ordem, numericality: { only_integer: true }, uniqueness: true

  scope :ordenados, -> { order(:ordem) }

  def self.proxima_ordem = (maximum(:ordem) || 0) + 1
end
