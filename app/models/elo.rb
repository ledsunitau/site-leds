# Degrau de pontuação do usuário (RF-EMB): Ferro, Bronze… até o topo. Os pontos
# vêm dos emblemas (peso do emblema × peso do rank atual — ver User#recalcular_elo!)
# e o elo é o maior degrau que couber neles.
#
# O elo FINAL é simplesmente o de maior pontos_minimos: é dentro dele que o
# ranking vira top 1..N. Sem coluna para marcá-lo — seria um segundo lugar para
# a mesma verdade, e daria para marcar dois.
class Elo < ApplicationRecord
  has_paper_trail

  has_many :users, dependent: :nullify

  validates :nome, presence: true, uniqueness: true
  validates :cor, format: { with: /\A#\h{6}\z/, message: "deve ser um hexadecimal como #00C55B" }
  validates :efeito, inclusion: { in: Emblema::EFEITOS }
  validates :pontos_minimos, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                             uniqueness: true
  validates :icone_svg, length: { maximum: Emblema::TAMANHO_MAX_SVG }

  # mesmo sanitizador do emblema: o ícone é markup vindo do painel
  before_validation :sanitizar_icone

  scope :ordenados, -> { order(:pontos_minimos) }
  scope :do_topo, -> { order(pontos_minimos: :desc) }

  # O degrau que os pontos alcançam. nil quando não há elo nenhum cadastrado ou
  # quando o usuário está abaixo do primeiro.
  def self.para(pontos) = do_topo.find_by("pontos_minimos <= ?", pontos.to_i)

  def self.final = do_topo.first

  def final? = self == self.class.final

  # Quantos pontos faltam para o próximo degrau; nil se já está no topo.
  def proximo = self.class.ordenados.find_by("pontos_minimos > ?", pontos_minimos)

  private

  def sanitizar_icone
    return if icone_svg.blank?

    self.icone_svg = ActionController::Base.helpers.sanitize(
      icone_svg, tags: Emblema::TAGS_SVG, attributes: Emblema::ATRIBUTOS_SVG
    ).to_s.strip
  end
end
