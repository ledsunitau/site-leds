# Organizadores e presentes numa junção só, diferenciados pelo papel
# (RF-ACO-04 — evita duas tabelas quase idênticas).
class EventoMembro < ApplicationRecord
  has_paper_trail

  belongs_to :evento
  belongs_to :member

  PAPEIS = %w[organizador participante].freeze
  enum :papel, PAPEIS.index_by(&:itself), validate: true

  validates :papel, uniqueness: { scope: [ :evento_id, :member_id ] }
end
