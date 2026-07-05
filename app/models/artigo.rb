class Artigo < ApplicationRecord
  has_paper_trail

  has_one :acao, as: :detalhe, dependent: :destroy
  has_many :autores, -> { order(:ordem) }, dependent: :destroy, inverse_of: :artigo
  has_many :apresentacoes, dependent: :destroy
  has_many :congressos, through: :apresentacoes
  has_many :artigo_temas, dependent: :destroy
  has_many :temas, through: :artigo_temas

  SITUACOES = %w[em_desenvolvimento finalizado].freeze
  enum :situacao, SITUACOES.index_by(&:itself), validate: true

  validate :coerencia_situacao_data
  # RN-18: mínimo de 1 tema na aplicação; máximo de 3 também no banco (trigger).
  validate :quantidade_de_temas

  # Card da ação (RF-ACO-05): situação + ícones dos temas.
  def card_json
    { situacao: situacao, data_finalizacao: data_finalizacao,
      temas: temas.with_attached_icone.map(&:card_json) }
  end

  private

  def coerencia_situacao_data
    if finalizado? && data_finalizacao.blank?
      errors.add(:data_finalizacao, "é obrigatória quando o artigo está finalizado")
    elsif em_desenvolvimento? && data_finalizacao.present?
      errors.add(:data_finalizacao, "deve ficar vazia enquanto o artigo está em desenvolvimento")
    end
  end

  def quantidade_de_temas
    quantidade = artigo_temas.reject(&:marked_for_destruction?).size
    errors.add(:temas, "o artigo precisa de 1 a 3 temas") unless (1..3).cover?(quantidade)
  end
end
