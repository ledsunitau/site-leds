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
  has_one_attached :foto

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

  def discord_username
    # find (não find_by): aproveita o preload de oauth_identities nas listagens
    identidade_discord&.username
  end

  # id do Discord (snowflake) = uid da oauth_identity; destino do DM (RF-NOT-04)
  def discord_uid
    identidade_discord&.uid
  end

  private

  def identidade_discord
    oauth_identities.find { |i| i.provider == "discord" }
  end
end
