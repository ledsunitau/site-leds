class Gestao < ApplicationRecord
  has_many :mandatos, dependent: :restrict_with_error

  validates :ano_inicio, presence: true, uniqueness: true
  validates :ano_fim, presence: true
  validate :ano_fim_maior_que_inicio

  # Resolver ÚNICO de "gestão vigente" — usado por cards, filtros, grafo e
  # geneograma. Se nenhuma gestão cobre o ano atual (lacuna entre trocas de
  # diretoria), vale a mais recente.
  def self.vigente
    ano = Date.current.year
    where("ano_inicio <= ? AND ano_fim >= ?", ano, ano).order(ano_inicio: :desc).first ||
      order(ano_inicio: :desc).first
  end

  private

  def ano_fim_maior_que_inicio
    return if ano_inicio.blank? || ano_fim.blank?

    errors.add(:ano_fim, "deve ser maior que o ano de início") if ano_fim <= ano_inicio
  end
end
