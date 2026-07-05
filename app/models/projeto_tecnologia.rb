class ProjetoTecnologia < ApplicationRecord
  has_paper_trail # RF-ADM-07: mudanças de stack também são auditadas

  belongs_to :projeto
  belongs_to :tecnologia

  validates :tecnologia_id, uniqueness: { scope: :projeto_id }
end
