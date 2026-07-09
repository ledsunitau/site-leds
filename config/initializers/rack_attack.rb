# RNF-15 — camada 2 (aplicação). A camada 1 (borda, por IP) é o proxy do
# Cloudflare, configurado na fase de deploy (feature/deploy-producao).
#
# Regra do projeto: toda branch que abrir um endpoint público de escrita
# adiciona o throttle correspondente AQUI, na mesma PR.
class Rack::Attack
  # As rotas do Devise aceitam sufixo de formato e barra final
  # (POST /users/sign_in.json chega à mesma action): normalizar antes de
  # comparar, senão todo throttle é contornável.
  def self.normalized_path(req)
    req.path.chomp("/").sub(/\.[^\/.]+\z/, "")
  end

  # Login: força bruta (RNF-03) — por IP e por e-mail tentado.
  throttle("logins/ip", limit: 10, period: 3.minutes) do |req|
    req.ip if req.post? && normalized_path(req) == "/users/sign_in"
  end

  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.post? && normalized_path(req) == "/users/sign_in"
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  # Cadastro e recuperação de senha: spam/abuso.
  throttle("signups/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/users"
  end

  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/users/password"
  end

  # Coleta de analytics (RN-14): folgado porque o cliente já manda em lote,
  # mas fecha o flood de eventos forjados contra o endpoint público.
  throttle("events/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.post? && normalized_path(req) == "/events"
  end

  # Consentimento: a decisão muda raramente; corta spam de gravação.
  throttle("consents/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/consents"
  end

  # Proposta de ideia (RF-IDE): submissão da comunidade — corta flood de spam.
  throttle("ideias/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/ideias"
  end
end

Rack::Attack.enabled = !Rails.env.test?
