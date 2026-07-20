# Pedido despachado (RF-LOJ-11): avisa o comprador com o código de rastreio.
# record = o Pedido.
class PedidoEnviadoNotifier < ApplicationNotifier
  CATEGORIA = "loja"

  def titulo = "Pedido enviado"

  # o código de rastreio pode não vir junto (transportadora atribui depois) —
  # só o inclui quando existe, senão a mensagem fica "Rastreio: " vazio.
  def mensagem
    base = "Seu pedido ##{record&.id} foi enviado."
    codigo = record&.rastreamento_codigo
    codigo.present? ? "#{base} Rastreio: #{codigo}." : base
  end

  def url = "/loja/pedidos/#{record&.id}"
end
