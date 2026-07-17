# Base dos notifiers (gem noticed). O registro in-app é gravado sempre; os
# três canais de SAÍDA abaixo são herdados por todo notifier e gateados pela
# preferência do destinatário (RF-NOT-06). config.if roda no contexto da
# Notification (instance_exec), onde `event` e `recipient` existem.
# Cada notifier concreto define CATEGORIA, titulo e mensagem; url é opcional.
class ApplicationNotifier < Noticed::Event
  deliver_by :email do |config|
    config.mailer = "NotificationMailer"
    config.method = :notify
    config.if = -> { event.entrega_externa? && event.canal_habilitado?(recipient, :email) }
  end

  deliver_by :web_push, class: "DeliveryMethods::WebPush" do |config|
    config.if = -> { event.entrega_externa? && event.canal_habilitado?(recipient, :push) }
  end

  deliver_by :discord_dm, class: "DeliveryMethods::DiscordDm" do |config|
    config.if = -> { event.entrega_externa? && event.canal_habilitado?(recipient, :discord) }
  end

  # Notifier disparado por endpoint ANÔNIMO sobrescreve para false: mandar
  # e-mail/push/DM com texto de quem não se autenticou transforma o nosso
  # pipeline confiável num amplificador de spam e phishing. Esses ficam só no
  # registro in-app (o centro/dashboard, que é onde a gestão vai olhar).
  def entrega_externa? = true

  def categoria = self.class::CATEGORIA

  def canal_habilitado?(destinatario, canal)
    NotificationPreference.habilitado?(user: destinatario, canal: canal, categoria: categoria)
  end

  # Conteúdo comum a todos os canais. Subclasses sobrescrevem titulo/mensagem.
  def titulo = raise(NotImplementedError)
  def mensagem = raise(NotImplementedError)
  def url = nil

  # URL absoluta para e-mail/discord (jobs não têm host de request).
  def link_absoluto
    host = ENV["APP_HOST"]
    "https://#{host}#{url}" if url && host.present?
  end
end
