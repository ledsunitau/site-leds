class Mandato < ApplicationRecord
  belongs_to :member
  belongs_to :gestao
  belongs_to :diretoria, optional: true

  CARGOS = %w[presidente vice diretor orientador membro].freeze

  enum :cargo, CARGOS.index_by(&:itself)

  validates :gestao_id, uniqueness: { scope: :member_id }
  validate :diretoria_coerente_com_cargo

  # Cargos de destaque alternam esquerda/direita no layout (RF-MEM-05).
  def destaque? = !membro?

  private

  # RN-05: presidente e vice não pertencem a diretoria. Diretor e membro
  # precisam de uma (é a aresta membro->diretor do grafo, RN-06); orientador
  # liga-se ao presidente, sem diretoria. Regra de negócio na aplicação,
  # não no banco — convenção da modelagem.
  def diretoria_coerente_com_cargo
    case cargo
    when "presidente", "vice", "orientador"
      errors.add(:diretoria, "não se aplica ao cargo #{cargo}") if diretoria_id.present?
    when "diretor", "membro"
      errors.add(:diretoria, "é obrigatória para o cargo #{cargo}") if diretoria_id.blank?
    end
  end
end
