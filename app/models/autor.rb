# Autores e coautores do artigo, membros OU externos: member_id nulo =
# autor externo; todos têm nome, lattes e ordem de autoria (RF-ACO-05).
class Autor < ApplicationRecord
  has_paper_trail

  belongs_to :artigo
  belongs_to :member, optional: true

  validates :nome, presence: true
  validates :ordem, numericality: { only_integer: true, greater_than: 0 }
end
