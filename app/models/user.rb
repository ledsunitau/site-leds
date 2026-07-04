class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2 discord]

  has_many :oauth_identities, dependent: :destroy
  has_one_attached :foto

  # Papel de ACESSO (autorização via Pundit). O cargo detalhado e histórico do
  # membro (presidente, diretor…) vive em mandatos — ver modelagem, Cluster 1.
  ROLES = %w[comunidade escritor parceiro membro diretoria presidencia].freeze
  enum :role, ROLES.index_by(&:itself), default: "comunidade"

  validates :name, presence: true
  validate :foto_deve_ser_imagem_pequena

  def discord_username
    oauth_identities.find_by(provider: "discord")&.username
  end

  private

  FOTO_TIPOS = %w[image/jpeg image/png image/webp].freeze
  FOTO_TAMANHO_MAX = 5.megabytes

  def foto_deve_ser_imagem_pequena
    return unless foto.attached?

    errors.add(:foto, "deve ser JPEG, PNG ou WebP") unless foto.content_type.in?(FOTO_TIPOS)
    errors.add(:foto, "deve ter no máximo 5 MB") if foto.byte_size > FOTO_TAMANHO_MAX
  end
end
