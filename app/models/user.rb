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

  validates :name, presence: true

  def discord_username
    # find (não find_by): aproveita o preload de oauth_identities nas listagens
    oauth_identities.find { |i| i.provider == "discord" }&.username
  end
end
