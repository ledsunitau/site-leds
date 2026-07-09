# Inscrição de Web Push do navegador (RF-NOT-02): endpoint + chaves VAPID
# (p256dh/auth). Um usuário pode ter várias (um por navegador/dispositivo).
# endpoint é único — reinscrever o mesmo navegador atualiza a linha.
class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh, :auth, presence: true
end
