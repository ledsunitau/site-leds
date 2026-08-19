# Reservas do modo sob demanda (RF-LOJ-05/06). Do próprio usuário — o escopo
# em current_user é a autorização (login basta, RN-17).
class ReservasController < ApplicationController
  include RecursoAtivo

  before_action :authenticate_user!
  # reservar É comprar: sem esta guarda, desligar a loja fechava catálogo e
  # checkout mas deixava a reserva sob demanda aceitando pedidos
  exige_recurso "loja_ativa", only: %i[create pagar]

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
    respond_to do |format|
      format.json { render json: reserva.card_json }
      format.html { redirect_to profile_path(anchor: "loja"), notice: "Reserva cancelada." }
    end
  end

  # RF-LOJ-07: pagar a reserva (após o disparo de produção) — cria o pedido e
  # devolve a URL de pagamento. A reserva só vira 'convertida' quando o
  # pagamento é aprovado (webhook).
  def pagar
    reserva = current_user.reservas.find(params[:id])
    pedido = Checkout.da_reserva(reserva)
    init_point = Pagamentos.iniciar(pedido)

    respond_to do |format|
      format.json { render json: { pedido: pedido.card_json, pagamento_url: init_point }, status: :created }
      format.html { redirect_to init_point, allow_other_host: true } # vai pro gateway
    end
  rescue Checkout::Erro => e
    respond_to do |format|
      format.json { render json: { errors: [ e.message ] }, status: :unprocessable_entity }
      format.html { redirect_to profile_path(anchor: "loja"), alert: e.message }
    end
  rescue MercadoPago::ErroGateway
    msg = "Pagamento indisponível no momento. Tente novamente."
    respond_to do |format|
      format.json { render json: { errors: [ msg ] }, status: :service_unavailable }
      format.html { redirect_to profile_path(anchor: "loja"), alert: msg }
    end
  end
end
