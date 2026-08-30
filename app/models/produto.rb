# Produto da loja (RF-LOJ-01). O modo_venda é o que faz tudo funcionar
# (RF-LOJ-03/RN-09): configurável por produto e reversível.
#   estoque     → disponibilidade vem de variantes.estoque
#   sob_demanda → vem de quantidade_alvo (a meta que dispara a produção)
# Cadastro/edição é auditado (RF-LOJ-09/RN-13).
class Produto < ApplicationRecord
  include ImagemValidavel

  has_paper_trail # RF-LOJ-09/RN-13: quem, quando, o quê mudou

  belongs_to :criador, class_name: "Member", foreign_key: :created_by,
                       optional: true, inverse_of: false
  belongs_to :categoria, optional: true
  has_many :variantes, dependent: :destroy
  has_many :avaliacoes, dependent: :destroy
  has_many :itens_carrinho, class_name: "ItemCarrinho", dependent: :destroy
  has_many :reservas, dependent: :restrict_with_exception # DDL: ON DELETE RESTRICT
  # DDL: itens_pedido.produto_id é ON DELETE RESTRICT (histórico de venda protege o produto)
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :restrict_with_exception

  # desvio documentado: o DDL não tem coluna de imagem — é Active Storage,
  # como tecnologias/temas (a modelagem lista "imagem de produto")
  # :card é o card do catálogo (4/5, ~320px) em 2x; :full é a foto principal do
  # detalhe e o lightbox com zoom, onde a pessoa REALMENTE olha de perto.
  has_one_attached :imagem do |anexo|
    anexo.variant :card, resize_to_limit: [ 640, 800 ], **ImagemValidavel::VARIANTE
    anexo.variant :full, resize_to_limit: [ 1200, 1500 ], **ImagemValidavel::VARIANTE
  end
  valida_imagem :imagem
  # Galeria do detalhe (#LOJA3): fotos extras além da principal. A view mostra
  # [imagem] + galeria: 3 miniaturas, "+N" no resto e o lightbox com todas.
  has_many_attached :galeria do |anexo|
    anexo.variant :card, resize_to_limit: [ 640, 800 ], **ImagemValidavel::VARIANTE
    anexo.variant :full, resize_to_limit: [ 1200, 1500 ], **ImagemValidavel::VARIANTE
  end
  # SVG entra aqui e não na principal pelo mesmo motivo do logo de parceiro: o
  # Active Storage serve svg+xml como binário (content_types_to_serve_as_binary),
  # então não executa script no navegador de ninguém. O seed usa SVG como
  # stand-in das fotos de demonstração.
  valida_imagem :galeria, tipos: ImagemValidavel::TIPOS + %w[image/svg+xml],
                          formatos: "JPEG, PNG, WebP ou SVG"
  # SEM teto de quantidade: a gestão sobe quantas fotos quiser (pedido do
  # usuário). Existia um MAX_FOTOS = 6 justificado como "regra do display", mas
  # o display nunca precisou dele — a tira de miniaturas já mostra 3 e colapsa o
  # resto em "+N", e o lightbox é um carrossel. O custo real de muitas fotos é
  # peso de página e geração de variante, não quebra de layout.

  # Todas as fotos do detalhe (principal primeiro), como objetos que o
  # rails_blob_path aceita. Vazio se não houver nenhuma.
  #
  # Devolve os ATTACHMENTS da galeria, não os blobs: variante nomeada
  # (:card/:full) é resolvida pela reflection do anexo, coisa que ActiveStorage::Blob
  # não conhece — com .map(&:blob) o FotoUrl cairia calado no original.
  def fotos
    principal = imagem.attached? ? [ imagem ] : []
    principal + galeria.attachments
  end

  MODOS_VENDA = %w[estoque sob_demanda].freeze
  STATUSES = %w[ativo indisponivel].freeze
  enum :modo_venda, MODOS_VENDA.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  # RF-LOJ-08/RN-11: marcar indisponivel limpa carrinhos e cancela reservas —
  # isso é o TRIGGER produto_indisponivel no banco (roda no UPDATE, atômico). À
  # aplicação cabe só notificar os reservantes DEPOIS. Capturo os afetados ANTES
  # do trigger cancelar (no after_commit já estariam 'cancelada'), e disparo no
  # after_commit para o registro já estar persistido.
  #
  # LIMITAÇÃO: só o caminho ActiveRecord notifica. update_column/update_all/SQL
  # cru pulam os callbacks — o trigger ainda cancela/limpa (é DB), mas ninguém é
  # avisado. Não use esses atalhos para (in)disponibilizar produto.
  before_update :capturar_reservantes_afetados, if: :vai_ficar_indisponivel?
  after_update_commit :notificar_reservantes, if: -> { @reservantes_afetados.present? }
  # rollback NÃO chama o after_commit: sem isto o ivar sobreviveria a um save
  # que reverteu e dispararia notificação falsa num save posterior da instância.
  after_rollback { @reservantes_afetados = nil }

  validates :nome, presence: true
  validates :preco, numericality: { greater_than_or_equal_to: 0 }
  validates :preco_promocional, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :quantidade_alvo, numericality: { greater_than: 0 }, allow_nil: true
  # REGRA ADICIONADA (não está no DDL nem literal no spec): sem meta, "sob
  # demanda" não tem o que disparar (RF-LOJ-05) e o produto nasce irreservável.
  # A coluna é nullable porque o modo estoque não a usa — nullable na tabela não
  # quer dizer opcional NESTE modo. Custo: trocar para sob_demanda exige mandar
  # a meta junto (RN-09 segue reversível, só não em um campo só).
  validates :quantidade_alvo, presence: true, if: :sob_demanda?
  # REGRA ADICIONADA: promoção acima do preço não é promoção, é dígito trocado —
  # e preco_atual é o que o pedido vai congelar, então o cliente pagaria MAIS
  # que o anunciado. Nenhum caso legítimo é barrado.
  validate :promocional_nao_pode_superar_preco

  scope :ativos, -> { ativo }
  scope :destaques, -> { where(destaque: true) }
  scope :em_promocao, -> { where.not(preco_promocional: nil) }

  # Top-N mais vendidos para a home (#LOJA), completando com ativos recentes
  # quando ainda não houve vendas suficientes (no lançamento nada foi vendido).
  def self.mais_vendidos(n = 6)
    ids = ItemPedido.joins(:pedido).where(pedidos: { status: Pedido::PAGOS })
                    .group(:produto_id).order(Arel.sql("SUM(quantidade) DESC"))
                    .limit(n).pluck(:produto_id)
    # eager-load variantes/imagem: o card lê ambos (evita N+1 na vitrine)
    base = ativos.includes(:variantes, imagem_attachment: :blob)
    vendidos = base.where(id: ids).index_by(&:id)
    ordenados = ids.filter_map { |id| vendidos[id] }
    return ordenados if ordenados.size >= n

    completar = base.where.not(id: ordenados.map(&:id)).order(created_at: :desc).limit(n - ordenados.size)
    ordenados + completar.to_a
  end

  # O que o cliente paga hoje (RF-LOJ-10). O congelamento do preço pago é do
  # itens_pedido (snapshot), não daqui.
  def preco_atual = preco_promocional || preco

  def em_promocao? = preco_promocional.present?

  # Estrelas (#LOJA3): média e total das avaliações deste produto.
  def nota_media = avaliacoes.average(:nota)&.round(1)
  def avaliacoes_count = avaliacoes.count

  # Direito de avaliar (#LOJA4): tem pedido pago-ou-além com este produto?
  def comprado_por?(user)
    return false if user.nil?

    Pedido.where(comprador: user, status: Pedido::PAGOS)
          .joins(:itens).exists?(itens_pedido: { produto_id: id })
  end

  # usuários com reserva ativa neste produto (distintos) — alvo das notificações
  # de produção (disparo) e de indisponibilidade.
  def reservantes_ativos
    reservas.ativa.includes(:user).map(&:user).uniq
  end

  def card_json
    {
      id: id,
      nome: nome,
      modo_venda: modo_venda,
      status: status,
      preco: preco,
      preco_promocional: preco_promocional,
      preco_atual: preco_atual,
      imagem_url: FotoUrl.para(imagem)
    }
  end

  private

  def promocional_nao_pode_superar_preco
    return if preco_promocional.nil? || preco.nil?

    errors.add(:preco_promocional, "não pode ser maior que o preço") if preco_promocional > preco
  end

  def vai_ficar_indisponivel?
    status_changed? && indisponivel?
  end

  # ANTES do trigger cancelar: quem tem reserva ativa neste produto.
  def capturar_reservantes_afetados
    @reservantes_afetados = reservantes_ativos
  end

  def notificar_reservantes
    afetados = @reservantes_afetados
    @reservantes_afetados = nil
    ProdutoIndisponivelNotifier.with(record: self).deliver(afetados)
  end
end
