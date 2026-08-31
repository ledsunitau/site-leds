# Organizadores e presentes numa junção só, diferenciados pelo papel
# (RF-ACO-04 — evita duas tabelas quase idênticas).
class EventoMembro < ApplicationRecord
  has_paper_trail

  belongs_to :evento
  belongs_to :member

  # Mesma razão da Contribuicao: a lista é cadastro, não enum. organizador e
  # participante ficam protegidos na tabela porque a API separa as duas listas
  # por esses nomes.
  validates :papel, inclusion: { in: ->(_) { Funcao.nomes_de("evento") },
                                 message: "não é uma função cadastrada" }
  validates :papel, uniqueness: { scope: [ :evento_id, :member_id ] }
end
