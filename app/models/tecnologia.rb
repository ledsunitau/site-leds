class Tecnologia < ApplicationRecord
  include ImagemValidavel

  has_many :projeto_tecnologias, dependent: :destroy
  has_many :projetos, through: :projeto_tecnologias

  has_one_attached :icone # desvio documentado: DDL tem varchar, usamos Active Storage
  valida_imagem :icone

  validates :nome, presence: true, uniqueness: true

  # Um formato só para catálogo, resposta de create e stack do projeto.
  def card_json
    { id: id, nome: nome, icone_url: FotoUrl.para(icone) }
  end
end
