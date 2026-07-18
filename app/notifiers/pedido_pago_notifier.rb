# Pagamento aprovado (RF-LOJ-04): confirma a compra para o comprador.
# record = o Pedido.
class PedidoPagoNotifier < ApplicationNotifier
  CATEGORIA = "loja"

  def titulo = "Pagamento confirmado"
  def mensagem = "Seu pedido ##{record&.id} foi pago. Já estamos cuidando dele."
  def url = "/loja/pedidos/#{record&.id}"
end
