# Convidado EXTERNO do evento (não é membro nem user).
class Convidado < ApplicationRecord
  has_paper_trail

  belongs_to :evento
  has_many :links, class_name: "ConvidadoLink", dependent: :destroy

  validates :nome, presence: true
end
