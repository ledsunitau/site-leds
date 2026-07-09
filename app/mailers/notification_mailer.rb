# Canal e-mail das notificações (RF-NOT-03). Um método genérico serve todos os
# notifiers — o conteúdo (titulo/mensagem/link) vem do evento noticed.
class NotificationMailer < ApplicationMailer
  def notify
    @notification = params[:notification]
    @evento = @notification.event
    @destinatario = params[:recipient]

    mail(to: @destinatario.email, subject: @evento.titulo)
  end
end
