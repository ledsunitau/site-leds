# Reservas do modo sob demanda (RF-LOJ-05/06). Do próprio usuário — o escopo
# em current_user é a autorização (login basta, RN-17).
class ReservasController < ApplicationController
  before_action :authenticate_user!

  def index
    reservas = current_user.reservas.includes(produto: { imagem_attachment: :blob }, variante: {})
                           .order(created_at: :desc)
    render json: { reservas: reservas.map(&:card_json) }
  end

  def create
    reserva = current_user.reservas.create!(
      params.expect(reserva: %i[produto_id variante_id quantidade])
    )
    render json: reserva.card_json, status: :created
  end

  # RF-LOJ-06/RN-10: cancelar antes do disparo (soft — vira 'cancelada')
  def cancelar
    reserva = current_user.reservas.find(params[:id])
    reserva.cancelar!
    render json: reserva.card_json
  end
end
