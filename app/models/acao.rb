# Núcleo das Ações (RF-ACO): o comum (título, status, autor) vive aqui;
# o específico vive no detalhe delegado (Projeto; Evento e Artigo chegam na
# próxima branch). Destruição SEMPRE via Acao (dependent: :destroy leva o
# detalhe junto; não há FK em detalhe_id — integridade na aplicação).
class Acao < ApplicationRecord
  include ImagemValidavel

  has_paper_trail # RF-ACO-06/RNF-09: criar/editar ações é auditado

  delegated_type :detalhe, types: %w[Projeto Evento Artigo], dependent: :destroy
  belongs_to :criador, class_name: "Member", foreign_key: :created_by, optional: true
  # idealizador (RF-ACO-07): a ação pode nascer de uma ideia aprovada
  belongs_to :ideia, optional: true, inverse_of: :acao

  has_one_attached :thumbnail # RF-ACO-10: todo card tem thumbnail
  valida_imagem :thumbnail

  STATUSES = %w[rascunho publicada arquivada].freeze
  # validate: true — status inválido vira erro 422 normal, não ArgumentError
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :titulo, presence: true
  # uma ideia vira no MÁXIMO uma ação (modelagem C3). ATENÇÃO: diferente de
  # detalhe_id (que TEM índice unique no DDL), o index_acoes_on_ideia é
  # não-unique por decisão do DDL — então esta unicidade é SÓ app-level e tem
  # janela de corrida (dois creates concorrentes com o mesmo ideia_id passam).
  # ponytail: app-level por autoridade do DDL; virar índice parcial unique é
  # decisão do dono do schema (levantado na entrega da branch).
  validates :ideia_id, uniqueness: true, allow_nil: true
  validate :ideia_deve_estar_aprovada, if: :ideia_id?
  # o idealizador é fixado na criação (RF-ACO-07) — não se re-aponta depois
  validate :ideia_id_imutavel, on: :update

  scope :publicadas, -> { where(status: "publicada") }

  private

  # só ideia aprovada vira ação (RF-IDE-04 → RF-ACO-07)
  def ideia_deve_estar_aprovada
    errors.add(:ideia, "precisa estar aprovada") unless ideia&.aprovada?
  end

  def ideia_id_imutavel
    errors.add(:ideia_id, "não pode mudar depois de criada") if ideia_id_changed?
  end
end
