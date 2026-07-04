class User < ApplicationRecord
  include FotoValidavel

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2 discord]

  has_many :oauth_identities, dependent: :destroy
  # dependent: :destroy espelha o ON DELETE CASCADE do banco, mas via
  # callbacks — necessário para o Active Storage purgar a foto do membro.
  has_one :member, dependent: :destroy
  has_one_attached :foto

  # Papel de ACESSO (autorização via Pundit). O cargo detalhado e histórico do
  # membro (presidente, diretor…) vive em mandatos — ver modelagem, Cluster 1.
  ROLES = %w[comunidade escritor parceiro membro diretoria presidencia].freeze
  enum :role, ROLES.index_by(&:itself), default: "comunidade"

  validates :name, presence: true

  def discord_username
    # find (não find_by): aproveita o preload de oauth_identities nas listagens
    oauth_identities.find { |i| i.provider == "discord" }&.username
  end
end
