# Novidades (RF-NOV): notícia e blog no mesmo modelo — a diferença é quem
# pode escrever cada tipo (PostPolicy). Corpo = Action Text; histórico de
# versões = PaperTrail (RF-NOV-07); publicação passa pela máquina de estados
# de status, nunca por atribuição direta (RN-02).
#
# atenção: a coluna "caller" (chamada do card, nome do DDL) sombreia
# Kernel#caller dentro do model — para backtrace use Kernel.caller.
class Post < ApplicationRecord
  include ImagemValidavel

  has_paper_trail

  belongs_to :autor, class_name: "User", foreign_key: :user_id,
                     optional: true, inverse_of: :posts
  belongs_to :aprovador, class_name: "Member", foreign_key: :approved_by,
                         optional: true, inverse_of: false

  has_rich_text :corpo
  has_one_attached :thumbnail
  valida_imagem :thumbnail

  TIPOS = %w[noticia blog].freeze
  STATUSES = %w[rascunho em_aprovacao publicado rejeitado].freeze
  # validate: true — valor inválido vira erro 422 normal, não ArgumentError
  enum :tipo, TIPOS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições SÓ pelo fluxo (submeter!/aprovar!/rejeitar!): o update! direto
  # dos bangs do enum pularia aprovador/approved_at/published_at (RF-NOV-05)
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :titulo, presence: true

  scope :publicados, -> { publicado }

  # RF-NOV-06/RN-02: qualquer edição de conteúdo em post publicado volta para
  # a fila — a aprovação antiga não vale para o conteúdo novo. Vive no model
  # para valer em TODO caminho de escrita (controller, admin futuro, console).
  before_update :retornar_para_aprovacao, if: :edicao_de_publicado?

  # RF-NOV-11 (modelagem, Cluster 5): o anúncio dispara sempre que o status
  # VIRA publicado — inclusive re-aprovação de edição. after_commit: o job não
  # pode rodar antes do post publicado existir de fato no banco.
  after_commit :anunciar_no_discord, if: -> { saved_change_to_status? && publicado? }

  # O cache da landing (posts/ultimas) não pode servir notícia que saiu do ar
  # (retirada, rejeitada, apagada) — TTL cobre frescor, não retratação.
  after_commit :expirar_cache_de_ultimas,
               if: -> { noticia? && (destroyed? || saved_change_to_status?) }

  # --- máquina de estados (RN-02): rascunho → em_aprovacao → publicado/rejeitado ---

  def submeter!
    transicionar!(de: %w[rascunho rejeitado], para: "em_aprovacao")
  end

  # RF-NOV-05: registra quem liberou. published_at só é gravado na PRIMEIRA
  # publicação — re-aprovar edição (RF-NOV-06) não fura a fila das últimas.
  def aprovar!(aprovador)
    transicionar!(de: %w[em_aprovacao], para: "publicado") do
      self.aprovador = aprovador
      self.approved_at = Time.current
      self.published_at ||= Time.current
    end
  end

  # Quem rejeitou fica no whodunnit da versão (PaperTrail) — o DDL só tem
  # approved_by, que é da liberação.
  def rejeitar!
    transicionar!(de: %w[em_aprovacao], para: "rejeitado")
  end

  private

  def retornar_para_aprovacao
    self.status = "em_aprovacao"
    self.aprovador = nil
    self.approved_at = nil
  end

  # O corpo (Action Text) e a thumbnail vivem fora da tabela posts — checar só
  # changed? deixaria edição só-de-corpo passar sem re-aprovação (RN-02).
  # status_changed? exclui as próprias transições (aprovar! etc.).
  def edicao_de_publicado?
    publicado? && !status_changed? &&
      (changed? || rich_text_corpo&.changed? || attachment_changes.any?)
  end

  # with_lock: duas aprovações simultâneas passariam ambas no guard lido em
  # memória (anúncio em dobro); o lock relê a linha antes de checar.
  def transicionar!(de:, para:)
    with_lock do
      unless de.include?(status)
        errors.add(:status, "não pode ir de #{status} para #{para}")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      self.status = para
      yield if block_given?
      save!
    end
  end

  def anunciar_no_discord
    DiscordWebhookJob.perform_later(id)
  end

  def expirar_cache_de_ultimas
    Rails.cache.delete("posts/ultimas")
  end
end
