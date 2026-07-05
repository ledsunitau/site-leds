# Núcleo das Ações (RF-ACO): o comum (título, status, autor) vive aqui;
# o específico vive no detalhe delegado (Projeto; Evento e Artigo chegam na
# próxima branch). Destruição SEMPRE via Acao (dependent: :destroy leva o
# detalhe junto; não há FK em detalhe_id — integridade na aplicação).
class Acao < ApplicationRecord
  include ImagemValidavel

  has_paper_trail # RF-ACO-06/RNF-09: criar/editar ações é auditado

  delegated_type :detalhe, types: %w[Projeto Evento Artigo], dependent: :destroy
  belongs_to :criador, class_name: "Member", foreign_key: :created_by, optional: true

  has_one_attached :thumbnail # RF-ACO-10: todo card tem thumbnail
  valida_imagem :thumbnail

  STATUSES = %w[rascunho publicada arquivada].freeze
  # validate: true — status inválido vira erro 422 normal, não ArgumentError
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :titulo, presence: true

  scope :publicadas, -> { where(status: "publicada") }
end
