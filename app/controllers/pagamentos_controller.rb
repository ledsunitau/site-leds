# Webhook de pagamento do Mercado Pago (RF-LOJ-12). Público e sem sessão — quem
# chama é o gateway, não o usuário, então não há CSRF a proteger. Duas defesas:
# (1) a assinatura HMAC do MP (quando há secret), que barra chamadas forjadas
# antes de qualquer trabalho; (2) reler o pagamento na API (fonte da verdade),
# que escopa ao nosso token. Sempre 200 nos erros nossos para o MP não reenviar
# infinitamente (só 401 quando a assinatura é inválida — aí não é o MP chamando).
class PagamentosController < ApplicationController
  skip_forgery_protection

  def webhook
    return head :unauthorized unless assinatura_valida?

    payment_id = params.dig(:data, :id) || params[:id]
    tipo = params[:type] || params[:topic]

    Pagamentos.confirmar_por_webhook(payment_id) if tipo == "payment" && payment_id.present?
    head :ok
  rescue MercadoPago::ErroGateway, ActiveRecord::RecordInvalid => e
    # gateway fora do ar, ou corrida de estado (pedido cancelado entre o guard e
    # o lock): 200 mesmo assim, o MP reenvia. Não pode virar loop de retry por 500.
    Rails.logger.warn("Webhook MP: #{e.class} — #{e.message}")
    head :ok
  end

  private

  # HMAC do MP (header x-signature: "ts=...,v1=..."). Sem secret configurado,
  # confia no re-fetch (a consulta à API é a fonte da verdade) — assim um secret
  # ainda-placeholder não rejeita webhooks reais em produção por engano.
  def assinatura_valida?
    secret = ENV["MERCADO_PAGO_WEBHOOK_SECRET"].presence
    return true if secret.nil?

    assinatura = request.headers["x-signature"].to_s
    ts = assinatura[/ts=([^,]+)/, 1]
    v1 = assinatura[/v1=([^,]+)/, 1]
    return false if ts.blank? || v1.blank?

    manifesto = "id:#{params.dig(:data, :id)};request-id:#{request.headers['x-request-id']};ts:#{ts};"
    esperado = OpenSSL::HMAC.hexdigest("SHA256", secret, manifesto)
    ActiveSupport::SecurityUtils.secure_compare(esperado, v1)
  end
end
