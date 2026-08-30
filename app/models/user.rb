class User < ApplicationRecord
  include ImagemValidavel
  valida_imagem :foto

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2 discord]

  has_many :oauth_identities, dependent: :destroy
  # dependent: :destroy espelha o ON DELETE CASCADE do banco, mas via
  # callbacks — necessário para o Active Storage purgar a foto do membro.
  has_one :member, dependent: :destroy
  # espelha o ON DELETE SET NULL do banco: o post sobrevive ao autor
  has_many :posts, dependent: :nullify, inverse_of: :autor
  # Notificações (gem noticed): destinatário restrito a User (modelagem C6).
  # noticed_notifications não tem FK (recipient polimórfico) — dependent limpa.
  has_many :notifications, as: :recipient, dependent: :destroy,
                           class_name: "Noticed::Notification"
  has_many :notification_preferences, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  # espelha o ON DELETE SET NULL: a ideia sobrevive ao autor (RN-01)
  has_many :ideias, dependent: :nullify, inverse_of: :autor
  # conta vinculada ao parceiro (RF-PAR-05); o parceiro sobrevive à conta
  has_one :parceiro, dependent: :nullify, inverse_of: :conta
  # espelham o ON DELETE SET NULL: comentário/denúncia sobrevivem ao autor
  has_many :comentarios, dependent: :nullify, inverse_of: :autor
  has_many :denuncias, dependent: :nullify, inverse_of: :denunciante
  # loja: um carrinho por usuário; reservas (ambos cascade no banco)
  has_one :carrinho, dependent: :destroy
  has_many :reservas, dependent: :destroy
  has_many :enderecos, dependent: :destroy
  # o pedido sobrevive à conta apagada (ON DELETE SET NULL) — histórico de venda
  has_many :pedidos, dependent: :nullify, inverse_of: :comprador
  # espelha o ON DELETE SET NULL: a avaliação anonimiza, não some (LGPD)
  has_many :avaliacoes, dependent: :nullify, inverse_of: :autor, foreign_key: :user_id
  # Emblemas (RF-EMB): desbloqueados + os dois equipados. cascade no banco.
  has_many :emblema_usuarios, dependent: :destroy
  has_many :emblemas, through: :emblema_usuarios
  # QUATRO slots de customização, todos independentes (RF-EMB):
  #   destaque/secundario — VITRINE: aparecem grandes no perfil e não pintam nada
  #   nome/halo           — PINTURA: a cor exclusiva que cada emblema desbloqueia,
  #                         e dá para misturar (o nome de um, o halo de outro)
  belongs_to :emblema_destaque, class_name: "Emblema", optional: true, inverse_of: false
  belongs_to :emblema_secundario, class_name: "Emblema", optional: true, inverse_of: false
  belongs_to :emblema_nome, class_name: "Emblema", optional: true, inverse_of: false
  belongs_to :emblema_halo, class_name: "Emblema", optional: true, inverse_of: false

  # Os slots, na ordem em que a tela de customização os mostra. Lista única —
  # validação, formulário e limpeza na revogação leem daqui.
  SLOTS = %i[emblema_destaque_id emblema_secundario_id emblema_nome_id emblema_halo_id].freeze
  # os que exigem que o emblema tenha pintura (gradiente) para valer
  SLOTS_DE_PINTURA = %i[emblema_nome_id emblema_halo_id].freeze
  # elo: degrau alcançado pelos pontos dos emblemas (ver recalcular_elo!)
  belongs_to :elo, optional: true
  # DOIS tamanhos porque há dois usos com ordens de grandeza diferentes — e
  # confundi-los foi um bug real: a foto do card em /membros saía a 96px num box
  # de 300×360 e ficava pixelada.
  #
  #   :avatar  — cromo da interface: navbar (38), drawer (52), pódio (58) e o
  #              avatar do perfil (84). 192 = o maior deles em 2x.
  #   :retrato — .membro-foto, que é 300×360 no desktop. Precisa 600×720 em 2x;
  #              uma foto 3:4 vira 675×900 aqui, com folga.
  #
  # E cada uma usa uma TRANSFORMAÇÃO diferente, porque os dois displays são
  # diferentes:
  #
  #   _fill no :avatar — todo avatar do site é um quadrado com border-radius:50%
  #   e object-fit:cover. A proporção é sempre 1:1, em qualquer breakpoint, então
  #   o corte quadrado no servidor é exatamente o que a tela faz. Com _limit uma
  #   foto 3:4 sairia 144×192 e o lado curto (144) ficaria abaixo dos 168 que o
  #   avatar do perfil pede em 2x.
  #
  #   _limit no :retrato — aqui a proporção INVERTE por breakpoint: abaixo de
  #   720px o card vira uma coluna e a foto passa de retrato (300×360) para
  #   paisagem (largura cheia × 240). Nenhum corte fixo serve os dois, e um 16:9
  #   para agradar o mobile cortaria a cabeça da pessoa no desktop. O corte fica
  #   com o CSS, que já o faz por breakpoint.
  #
  # Member#foto declara as MESMAS variantes: foto_para_card cai aqui quando o
  # membro não tem foto própria, e variant(:nome) levanta para nome não
  # declarado.
  has_one_attached :foto do |anexo|
    anexo.variant :avatar,  resize_to_fill:  [ 192, 192 ], **ImagemValidavel::VARIANTE
    anexo.variant :retrato, resize_to_limit: [ 720, 900 ], **ImagemValidavel::VARIANTE
  end

  # Papel de ACESSO (autorização via Pundit). O cargo detalhado e histórico do
  # membro (presidente, diretor…) vive em mandatos — ver modelagem, Cluster 1.
  ROLES = %w[comunidade escritor parceiro membro diretoria presidencia].freeze
  # Papéis com poder de gestão — fonte ÚNICA da definição (policies e o gate
  # do /admin derivam daqui; ver ApplicationPolicy#gestor?).
  ROLES_DE_GESTAO = %w[diretoria presidencia].freeze
  # validate: true — role inválido vira 422 normal, não ArgumentError
  enum :role, ROLES.index_by(&:itself), default: "comunidade", validate: true

  def gestao? = ROLES_DE_GESTAO.include?(role)

  # Destinatários da gestão (fila de aprovação, moderação). Fonte única = ROLES_DE_GESTAO.
  scope :gestao, -> { where(role: ROLES_DE_GESTAO) }

  validates :name, presence: true
  validate :emblemas_equipados_desbloqueados
  validate :destaque_diferente_do_secundario
  validate :cosmetico_tem_pintura

  def discord_username
    # find (não find_by): aproveita o preload de oauth_identities nas listagens
    identidade_discord&.username
  end

  # id do Discord (snowflake) = uid da oauth_identity; destino do DM (RF-NOT-04)
  def discord_uid
    identidade_discord&.uid
  end

  # Ações publicadas creditadas ao usuário no "Meu perfil": as que participou
  # como membro (Contribuicao/EventoMembro/Autor) + as que idealizou (ideia
  # aprovada que virou ação — RF-ACO-07, via acoes.ideia_id). Union sem duplicar.
  def acoes_creditadas
    ids = member&.acoes_participadas&.ids || []
    ids |= Acao.publicadas.where(ideia_id: ideias.select(:id)).ids
    Acao.publicadas.where(id: ids).order(created_at: :desc)
  end

  # Pontos e elo (RF-EMB). Pontos = Σ (peso do emblema × peso do rank atual);
  # emblema único, que não tem rank, conta ×1 pelo COALESCE.
  #
  # Denormalizado em users porque o ranking é um ORDER BY e o elo aparece em
  # toda página de perfil — recalcular na leitura seria uma agregação por
  # pageview. Reescrito onde os pontos podem mudar: conceder, revogar, subir de
  # rank e a varredura do EmblemasJob.
  def recalcular_elo!
    pontos = EmblemaUsuario.where(user_id: id)
                           .joins(:emblema)
                           .joins("LEFT JOIN emblema_niveis ON emblema_niveis.id = emblema_usuarios.nivel_id")
                           .joins("LEFT JOIN emblema_ranks ON emblema_ranks.id = emblema_niveis.rank_id")
                           .sum("emblemas.peso * COALESCE(emblema_ranks.peso, 1)")
    novo = Elo.para(pontos)
    return if pontos == pontos_emblemas && novo&.id == elo_id

    anterior = elo
    # update_columns: não passa pelas validações de emblema equipado (que nada
    # têm a ver com pontuação) nem dispara callbacks numa escrita de bastidor.
    update_columns(pontos_emblemas: pontos, elo_id: novo&.id)

    return if anterior&.id == novo&.id

    DiscordCargoJob.perform_later(id, anterior.discord_role_id, "remover") if anterior&.discord_role_id.present?
    DiscordCargoJob.perform_later(id, novo.discord_role_id, "adicionar") if novo&.discord_role_id.present?
  end

  # Posição no ranking do elo mais alto (1, 2, 3…). nil se não está nele.
  def posicao_no_topo
    return nil if elo.nil? || !elo.final?

    User.where(elo_id: elo_id).where("pontos_emblemas > ?", pontos_emblemas).count + 1
  end

  private

  def identidade_discord
    oauth_identities.find { |i| i.provider == "discord" }
  end

  # Equipar só o que é seu. Sem isto, um PATCH com id arbitrário exibiria no
  # perfil um emblema que o usuário nunca conquistou — ou vestiria uma pintura
  # exclusiva sem ter feito nada por ela.
  def emblemas_equipados_desbloqueados
    ids = SLOTS.filter_map { |slot| public_send(slot) }.uniq
    return if ids.empty?

    desbloqueados = EmblemaUsuario.where(user_id: id, emblema_id: ids).pluck(:emblema_id)
    return if (ids - desbloqueados).empty?

    errors.add(:base, "Você só pode equipar emblemas que já desbloqueou.")
  end

  # Emblema sem gradiente não tem pintura para vestir. Sem esta guarda o usuário
  # escolheria uma cor que não existe e ficaria com o nome branco sem entender
  # por quê.
  def cosmetico_tem_pintura
    SLOTS_DE_PINTURA.each do |slot|
      emblema = public_send(slot.to_s.delete_suffix("_id"))
      next if emblema.nil? || emblema.cosmetico?

      errors.add(slot, "não tem cor exclusiva para usar")
    end
  end

  def destaque_diferente_do_secundario
    return if emblema_destaque_id.blank? || emblema_destaque_id != emblema_secundario_id

    errors.add(:emblema_secundario, "não pode ser o mesmo do destaque")
  end
end
