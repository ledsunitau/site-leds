class Projeto < ApplicationRecord
  has_paper_trail # link/situação/hospedagem auditados junto com a ação

  # dependent: :destroy nos dois sentidos: sem FK em acoes.detalhe_id,
  # destruir um Projeto direto órfãnaria a ação (500 no show público).
  has_one :acao, as: :detalhe, dependent: :destroy
  has_many :projeto_tecnologias, dependent: :destroy
  has_many :tecnologias, through: :projeto_tecnologias
  has_many :contribuicoes, dependent: :destroy
  has_many :membros, through: :contribuicoes, source: :member

  SITUACOES = %w[em_desenvolvimento finalizado].freeze
  enum :situacao, SITUACOES.index_by(&:itself), validate: true

  # Espelho da CHECK do banco: finalizado ⇒ tem data; em dev ⇒ sem data.
  validate :coerencia_situacao_data

  # Card da ação (RF-ACO-03): "em dev" ou a data de finalização. No model
  # porque a vitrine de parceiros (RF-PAR-02) também renderiza estes cards.
  def card_json
    { situacao: situacao, data_finalizacao: data_finalizacao }
  end

  private

  def coerencia_situacao_data
    if finalizado? && data_finalizacao.blank?
      errors.add(:data_finalizacao, "é obrigatória quando o projeto está finalizado")
    elsif em_desenvolvimento? && data_finalizacao.present?
      errors.add(:data_finalizacao, "deve ficar vazia enquanto o projeto está em desenvolvimento")
    end
  end
end
