class Evento < ApplicationRecord
  has_paper_trail

  has_one :acao, as: :detalhe, dependent: :destroy
  has_many :evento_membros, dependent: :destroy
  has_many :membros, through: :evento_membros, source: :member
  has_many :convidados, dependent: :destroy

  validates :data_inicio, presence: true
  validate :data_fim_apos_inicio

  def card_json
    { local: local, data_inicio: data_inicio, data_fim: data_fim, estado: estado }
  end

  # Estado DERIVADO das datas (decisão da modelagem — não é coluna).
  # Sem data_fim, o evento "acontece" até o fim do dia de início.
  def estado
    agora = Time.current
    return "vai_acontecer" if data_inicio > agora

    fim = data_fim || data_inicio.end_of_day
    agora <= fim ? "acontecendo" : "ja_aconteceu"
  end

  private

  def data_fim_apos_inicio
    return if data_fim.blank? || data_inicio.blank?

    errors.add(:data_fim, "deve ser depois do início") if data_fim < data_inicio
  end
end
