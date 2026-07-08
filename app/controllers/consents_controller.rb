# RNF-04/05: registra a escolha de cookies do visitante. Os essenciais são
# sempre implícitos (nem entram aqui); só analytics/marketing dependem do
# opt-in. Público — funciona logado ou anônimo (identificado pelo cookie
# anonymous_id, que é essencial e por isso pode ser gravado sem consentimento).
class ConsentsController < ApplicationController
  # Endpoint público sem sessão: o cliente é um beacon (sendBeacon/fetch), que
  # não anexa token CSRF. Sem sessão autenticada a proteger, o CSRF só quebra o
  # coletor legítimo — e o test env esconde isso (allow_forgery_protection=false).
  skip_forgery_protection

  def create
    anon = anonymous_id || gerar_anonymous_id

    consent = CookieConsent.create!(
      user: current_user,
      anonymous_id: anon,
      analytics: booleano(:analytics),
      marketing: booleano(:marketing),
      consented_at: Time.current,
      user_agent: request.user_agent
    )

    render json: {
      anonymous_id: anon,
      analytics: consent.analytics,
      marketing: consent.marketing
    }, status: :created
  end

  private

  # Cookie assinado (não forjável), permanente e httponly — o servidor é quem
  # lê na coleta. secure só em produção (dev/test rodam sobre http).
  def gerar_anonymous_id
    SecureRandom.uuid.tap do |novo|
      cookies.signed.permanent[:anonymous_id] = {
        value: novo, httponly: true, same_site: :lax, secure: Rails.env.production?
      }
    end
  end

  def booleano(chave)
    ActiveModel::Type::Boolean.new.cast(params[chave]) || false
  end
end
