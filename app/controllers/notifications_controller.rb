# Centro de notificações in-app (RF-NOT-01): lista as notificações do usuário
# e marca como lidas. As linhas são criadas pelo noticed em toda entrega.
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    escopo = current_user.notifications.includes(event: :record).newest_first

    render json: {
      nao_lidas: current_user.notifications.unread.count,
      notificacoes: paginar(escopo, por_pagina: 30).map { |n| notificacao_json(n) }
    }
  end

  def read
    current_user.notifications.find(params[:id]).mark_as_read!
    head :no_content
  end

  def read_all
    current_user.notifications.unread.mark_as_read
    head :no_content
  end

  private

  def notificacao_json(notificacao)
    evento = notificacao.event
    {
      id: notificacao.id,
      tipo: evento.type,
      titulo: evento.titulo,
      mensagem: evento.mensagem,
      url: evento.url,
      lida: notificacao.read?,
      criada_em: notificacao.created_at
    }
  end
end
