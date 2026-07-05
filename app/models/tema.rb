# Temas pré-definidos do artigo (nome + ícone) — no card aparecem os ícones,
# no hover o nome (RF-ACO-05). Catálogo via seeds; gestão vem na branch admin.
class Tema < ApplicationRecord
  include ImagemValidavel

  has_many :artigo_temas, dependent: :destroy
  has_many :artigos, through: :artigo_temas

  has_one_attached :icone # desvio documentado: DDL tem varchar
  valida_imagem :icone

  validates :nome, presence: true, uniqueness: true

  def card_json
    { id: id, nome: nome, icone_url: FotoUrl.para(icone) }
  end
end
