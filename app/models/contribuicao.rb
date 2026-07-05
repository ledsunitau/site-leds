# Quem fez o quê no projeto (RF-ACO-03). Um membro pode ter mais de um papel
# no mesmo projeto (único por projeto+membro+papel).
class Contribuicao < ApplicationRecord
  has_paper_trail # RF-ADM-07: trocar quem contribuiu também é "o que mudou"

  belongs_to :projeto
  belongs_to :member

  PAPEIS = %w[backend frontend ui_ux design infra outro].freeze
  enum :papel, PAPEIS.index_by(&:itself), validate: true

  validates :papel, uniqueness: { scope: [ :projeto_id, :member_id ] }
end
