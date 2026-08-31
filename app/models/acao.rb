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
  # parceiros que apoiam a ação (RF-PAR-02)
  has_many :acao_parceiros, dependent: :destroy
  has_many :parceiros, through: :acao_parceiros

  # RF-ACO-10: todo card tem thumbnail. :card serve a .acao-media, que é o
  # maior consumo — nenhuma tela mostra a thumbnail em tamanho original.
  has_one_attached :thumbnail do |anexo|
    anexo.variant :card, resize_to_limit: [ 640, 480 ], **ImagemValidavel::VARIANTE
  end
  valida_imagem :thumbnail

  STATUSES = %w[rascunho publicada arquivada].freeze
  # validate: true — status inválido vira erro 422 normal, não ArgumentError
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :titulo, presence: true
  # uma ideia vira no MÁXIMO uma ação (modelagem C3). Respaldada por índice
  # PARCIAL único (index_acoes_on_ideia_id WHERE ideia_id IS NOT NULL): a
  # validação dá a mensagem amigável no caso comum, o índice fecha a corrida de
  # creates concorrentes (RecordNotUnique → 422 no ApplicationController).
  validates :ideia_id, uniqueness: true, allow_nil: true
  validate :ideia_deve_estar_aprovada, if: :ideia_id?
  # o idealizador é fixado na criação (RF-ACO-07) — não se re-aponta depois
  validate :ideia_id_imutavel, on: :update

  scope :publicadas, -> { where(status: "publicada") }

  # Ordem da vitrine: pela data em que a ação ACONTECEU (evento: início;
  # projeto/artigo: finalização), não pela data em que foi cadastrada — é a
  # mesma data que o card mostra (data_da_acao). O detalhe é polimórfico, então
  # são três LEFT JOINs e um COALESCE; sem data (em desenvolvimento) a ação
  # está acontecendo AGORA e vai pro topo (NULLS FIRST), com o cadastro
  # desempatando. reorder porque o escopo de origem costuma vir por created_at.
  scope :por_data_do_acontecido, -> {
    joins(<<~SQL.squish)
      LEFT JOIN eventos ON acoes.detalhe_type = 'Evento' AND eventos.id = acoes.detalhe_id
      LEFT JOIN projetos ON acoes.detalhe_type = 'Projeto' AND projetos.id = acoes.detalhe_id
      LEFT JOIN artigos ON acoes.detalhe_type = 'Artigo' AND artigos.id = acoes.detalhe_id
    SQL
      .reorder(Arel.sql(
        "COALESCE(eventos.data_inicio, projetos.data_finalizacao, artigos.data_finalizacao) DESC NULLS FIRST, " \
        "acoes.created_at DESC"
      ))
  }

  private

  # só ideia aprovada vira ação (RF-IDE-04 → RF-ACO-07)
  def ideia_deve_estar_aprovada
    errors.add(:ideia, "precisa estar aprovada") unless ideia&.aprovada?
  end

  def ideia_id_imutavel
    errors.add(:ideia_id, "não pode mudar depois de criada") if ideia_id_changed?
  end
end
