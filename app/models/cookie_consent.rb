# Escolha de consentimento de cookies (RNF-04/05). Uma linha por decisão —
# guardamos o histórico, a vigente é a mais recente. Usuário opcional: cobre
# o visitante anônimo (identificado só pelo cookie anonymous_id).
class CookieConsent < ApplicationRecord
  belongs_to :user, optional: true

  # anônimo OU logado: sem nenhum dos dois a decisão não pertence a ninguém.
  validates :anonymous_id, presence: true, unless: :user_id?

  # Última decisão vigente para este visitante (logado tem prioridade sobre o
  # cookie). Fonte ÚNICA de "pode coletar?" — reusada pela coleta (RN-14).
  def self.vigente(user:, anonymous_id:)
    escopo = if user
               where(user_id: user.id)
    elsif anonymous_id.present?
               where(anonymous_id: anonymous_id)
    end
    escopo&.order(consented_at: :desc, id: :desc)&.first
  end

  def self.analytics_permitido?(user:, anonymous_id:)
    vigente(user:, anonymous_id:)&.analytics || false
  end
end
