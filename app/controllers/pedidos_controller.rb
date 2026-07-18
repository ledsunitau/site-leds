# Pedidos do próprio usuário (RF-LOJ-04): listar, ver, reiniciar pagamento e
# cancelar antes de pagar. Escopo em current_user é a autz (RN-17).
class PedidosController < ApplicationController
  before_action :authenticate_user!

  def index
    pedidos = current_user.pedidos.includes(itens: %i[produto variante]).order(created_at: :desc)
    render json: { pedidos: pedidos.map(&:card_json) }
  end

  def show
    render json: pedido.card_json
  end

  # reinicia o pagamento (nova preferência) — útil quando o gateway caiu no
  # checkout ou a tentativa anterior falhou (RF-LOJ-12: várias tentativas)
  def pagar
    init_point = Pagamentos.iniciar(pedido)
    render json: { pagamento_url: init_point }
  rescue MercadoPago::ErroGateway => e
    render json: { errors: [ e.message ] }, status: :service_unavailable
  end

  def cancelar
    pedido.cancelar!
    render json: pedido.card_json
  end

  private

  def pedido
    @pedido ||= current_user.pedidos.find(params[:id])
  end
end
