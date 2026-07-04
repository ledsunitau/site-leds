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
end

Rack::Attack.enabled = !Rails.env.test?
