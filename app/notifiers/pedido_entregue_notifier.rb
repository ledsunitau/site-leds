# Pedido entregue (RF-LOJ-11): fecha o ciclo com o comprador.
# record = o Pedido.
class PedidoEntregueNotifier < ApplicationNotifier
  CATEGORIA = "loja"

  def titulo = "Pedido entregue"
  def mensagem = "Seu pedido ##{record&.id} foi entregue. Bom proveito!"
  def url = "/loja/pedidos/#{record&.id}"
end
