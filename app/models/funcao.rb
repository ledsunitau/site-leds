# Funções (papéis) que uma pessoa exerce numa ação, por modalidade.
#
# Era lista fechada em três camadas (constante + enum + CHECK); virou cadastro
# para a gestão criar papel novo sem deploy. Contribuicao/EventoMembro guardam o
# `nome` em varchar, não o id — por isso renomear função em uso não é permitido
# pelo painel (as linhas antigas apontariam para um nome que sumiu).
class Funcao < ApplicationRecord
  MODALIDADES = %w[projeto evento].freeze

  validates :modalidade, inclusion: { in: MODALIDADES }
  validates :nome, presence: true, uniqueness: { scope: :modalidade }

  scope :de, ->(modalidade) { where(modalidade: modalidade).order(:nome) }

  def self.nomes_de(modalidade) = de(modalidade).pluck(:nome)
end
