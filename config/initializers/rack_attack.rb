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

  # Formulário público "seja um parceiro" (RF-PAR-03): sem login nenhum, é o
  # alvo mais óbvio de spam de formulário.
  throttle("parceria_leads/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/parceria_leads"
  end

  # Comentários e denúncias (RF-NOV-08/09): escrita da comunidade em massa —
  # o path varia (/posts/:id/comentarios, /comentarios/:id/denuncias), então
  # casa por prefixo/sufixo em vez de igualdade.
  throttle("comentarios/ip", limit: 30, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req).match?(%r{\A/posts/\d+/comentarios\z})
  end

  throttle("denuncias/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req).match?(%r{\A/comentarios/\d+/denuncias\z})
  end

  # Webhook do gateway (RF-LOJ-12): público, sem sessão. Cada POST pode virar uma
  # consulta ao MP — teto por IP corta amplificação/DoS. Folgado porque o MP
  # reenvia os legítimos (e reentrega os que estourarem o teto).
  throttle("pagamentos_webhook/ip", limit: 120, period: 1.minute) do |req|
    req.ip if req.post? && normalized_path(req) == "/pagamentos/webhook"
  end

  # Cotação de frete (RF-LOJ-11): cada POST pode chamar a API do Melhor Envio
  # (cota limitada, §7.3). O cache já corta a maioria; o throttle protege contra
  # varredura de CEPs que fura o cache.
  throttle("frete_cotar/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.post? && normalized_path(req) == "/frete/cotar"
  end

  # Checkout de envio também re-cota no Melhor Envio (varrer CEPs aqui furaria o
  # limite acima). Mesmo teto anti-cota na rota de checkout.
  throttle("checkout/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.post? && normalized_path(req) == "/checkout"
  end
end

Rack::Attack.enabled = !Rails.env.test?
