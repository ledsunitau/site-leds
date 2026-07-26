# Skill do membro (RF-MEM): reusa Tecnologia (nome + ícone) — o mesmo catálogo
# da stack dos projetos, então os ícones SVG do repo servem aos dois.
class MemberTecnologia < ApplicationRecord
  belongs_to :member
  belongs_to :tecnologia

  validates :tecnologia_id, uniqueness: { scope: :member_id }
end
