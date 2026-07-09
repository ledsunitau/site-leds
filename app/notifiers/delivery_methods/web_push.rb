# Canal push do navegador (RF-NOT-02). Envia o payload VAPID para cada
# inscrição do destinatário. Sem chaves VAPID configuradas, não faz nada
# (dev/prod sem push). Inscrição expirada/inválida é apagada — o navegador já
# descartou aquele endpoint.
module DeliveryMethods
  class WebPush < ApplicationDeliveryMethod
    def deliver
      return if vapid.blank?

      recipient.push_subscriptions.each { |sub| enviar(sub) }
    end

    private

    def enviar(sub)
      ::WebPush.payload_send(
        message: payload,
        endpoint: sub.endpoint, p256dh: sub.p256dh, auth: sub.auth,
        vapid: vapid
      )
    rescue ::WebPush::ExpiredSubscription, ::WebPush::InvalidSubscription
      sub.destroy # navegador cancelou/expirou — limpa a inscrição morta
    rescue ::WebPush::ResponseError => e
      # transiente (503/429) ou erro do serviço: não pode abortar os OUTROS subs
      # do mesmo usuário. Push é best-effort — a próxima notificação tenta de novo.
      Rails.logger.warn("WebPush falhou p/ sub #{sub.id}: #{e.class}")
    end

    def payload
      { title: event.titulo, body: event.mensagem, url: event.link_absoluto }.compact.to_json
    end

    def vapid
      pub = ENV["VAPID_PUBLIC_KEY"]
      priv = ENV["VAPID_PRIVATE_KEY"]
      return if pub.blank? || priv.blank?

      { subject: ENV.fetch("VAPID_SUBJECT", "mailto:contato@leds.org.br"),
        public_key: pub, private_key: priv }
    end
  end
end
