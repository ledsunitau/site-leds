# Congressos reutilizáveis (CICTED etc.).
class Congresso < ApplicationRecord
  has_many :apresentacoes, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: true

  def card_json
    { id: id, nome: nome }
  end
end
