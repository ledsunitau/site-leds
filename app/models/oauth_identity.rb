class OauthIdentity < ApplicationRecord
  # O omniauth chama o provedor Google de "google_oauth2"; o DDL guarda "google".
  PROVIDERS = { "google_oauth2" => "google", "discord" => "discord" }.freeze

  belongs_to :user

  validates :provider, inclusion: { in: PROVIDERS.values }
  validates :uid, presence: true, uniqueness: { scope: :provider }

  def self.normalize_provider(omniauth_provider)
    PROVIDERS.fetch(omniauth_provider.to_s, omniauth_provider.to_s)
  end
end
