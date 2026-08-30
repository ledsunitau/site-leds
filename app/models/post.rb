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
  # noticed usa record polimórfico SEM FK: sem esta limpeza, apagar um post
  # deixa notificações órfãs cujo record vira nil (500 no centro do usuário).
  # O Noticed::Event já apaga suas notifications em cascata (delete_all).
  has_many :noticed_events, as: :record, dependent: :destroy,
                            class_name: "Noticed::Event", inverse_of: :record

  # RF-NOV-08: comentários do post (cascade no banco; destroy leva junto)
  has_many :comentarios, dependent: :destroy

  has_rich_text :corpo
  # DUAS variantes porque os dois usos da capa têm tamanhos muito diferentes, e
  # servir a menor nos dois é exatamente o defeito que o b9bf7c7 corrigiu na foto
  # de membro:
  #   :card   720x480 — .novidade-media no grid/carrossel/relacionadas. A coluna
  #           do grid de 3 dá ~373px, então 720 cobre 2x.
  #   :banner 1600x900 — .artigo-banner da página da notícia, que mede 1180x506
  #           CSS (.wrap de 1260 menos 80 de padding, aspect-ratio 21/9). Recebia
  #           a :card de 640 e subia 1,8x — ~3,7x em tela HiDPI.
  has_one_attached :thumbnail do |anexo|
    anexo.variant :card,   resize_to_limit: [ 720, 480 ],  **ImagemValidavel::VARIANTE
    anexo.variant :banner, resize_to_limit: [ 1600, 900 ], **ImagemValidavel::VARIANTE
  end
  # 1200x630: a menor imagem que ainda cobre os 1180 de largura do banner sem
  # upscale. Abaixo disso nenhuma variante salva — resize_to_limit não amplia, e
  # quem amplia é o background-size:cover do CSS, na tela do leitor.
  valida_imagem :thumbnail, minimo: [ 1200, 630 ]

  TIPOS = %w[noticia blog].freeze
  # Modo do editor. "rico" = Trix/Action Text; "markdown" = o autor escreve o
  # fonte em corpo_markdown e ele é renderizado para o corpo ao salvar.
  FORMATOS = %w[rico markdown].freeze
  STATUSES = %w[rascunho em_aprovacao publicado rejeitado].freeze
  # validate: true — valor inválido vira erro 422 normal, não ArgumentError
  enum :tipo, TIPOS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :formato, FORMATOS.index_by(&:itself), validate: true
  # transições SÓ pelo fluxo (submeter!/aprovar!/rejeitar!): o update! direto
  # dos bangs do enum pularia aprovador/approved_at/published_at (RF-NOV-05)
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :titulo, presence: true
  validate :formato_nao_volta_para_markdown

  scope :publicados, -> { publicado }

  # Markdown é o FONTE; o corpo guarda o HTML renderizado dele. before_save (e
  # não before_update) para valer também na criação, e antes do
  # retornar_para_aprovacao logo abaixo — no Rails o before_save roda primeiro.
  before_save :renderizar_markdown, if: :precisa_renderizar_markdown?


  # RF-NOV-06/RN-02: qualquer edição de conteúdo em post publicado volta para
  # a fila — a aprovação antiga não vale para o conteúdo novo. Vive no model
  # para valer em TODO caminho de escrita (controller, admin futuro, console).
  before_update :retornar_para_aprovacao, if: :edicao_de_publicado?

  # RF-NOV-11 (modelagem, Cluster 5): o anúncio dispara sempre que o status
  # VIRA publicado — inclusive re-aprovação de edição. after_commit: o job não
  # pode rodar antes do post publicado existir de fato no banco.
  after_commit :anunciar_no_discord, if: -> { saved_change_to_status? && publicado? }

  # Notificações aos usuários (RF-NOT): fila → gestão (RF-ADM-04); resultado →
  # autor (RF-NOV-05). after_commit: destinatário só é avisado de estado já
  # persistido. Distinto do anúncio no canal (webhook), que é público.
  after_commit :notificar_moderacao, if: -> { saved_change_to_status? }

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

  # --- modo markdown ---

  def precisa_renderizar_markdown?
    formato_changed? || corpo_markdown_changed?
  end

  # formato_changed? entra na condição (e não só corpo_markdown_changed?) porque
  # o post pode ACABAR de virar markdown neste mesmo save — aí o fonte precisa
  # ser renderizado mesmo sem ter mudado.
  def renderizar_markdown
    if markdown?
      self.corpo = MarkdownRenderer.para_html(corpo_markdown)
    elsif formato_changed?
      # virou rico: o corpo renderizado continua valendo e passa a ser a verdade;
      # o fonte antigo some para não ficar um segundo texto, desatualizado, que
      # ninguém edita mas o histórico de versões continua mostrando.
      self.corpo_markdown = nil
    end
  end

  # Troca de modo é de mão única: markdown → rico aproveita o corpo que já está
  # renderizado; rico → markdown não tem de onde tirar o fonte. Converter o HTML
  # de volta exigiria outra dependência e perderia formatação em toda ida-e-volta
  # — melhor recusar do que degradar o texto de alguém em silêncio.
  def formato_nao_volta_para_markdown
    return unless persisted? && formato_changed?(from: "rico", to: "markdown")

    errors.add(:formato, "não pode voltar para markdown: o texto já está no editor rico e a conversão de volta perderia formatação")
  end

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

  def notificar_moderacao
    case status
    when "em_aprovacao"
      gestores = User.gestao.where.not(id: user_id).to_a # não notifica o próprio autor gestor
      PostSubmetidoNotifier.with(record: self).deliver(gestores) if gestores.any?
    when "publicado", "rejeitado"
      PostModeradoNotifier.with(record: self, resultado: status).deliver(autor) if autor
    end
  end

  def expirar_cache_de_ultimas
    Rails.cache.delete("posts/ultimas")
  end
end
