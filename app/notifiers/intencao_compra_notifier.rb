# Intenção de compra (modo "direto", sem Mercado Pago): alguém finalizou um
# pedido e a gestão precisa fechar por contato. Avisa a gestão com quem, contato
# e o que foi pedido. record = o Pedido.
#
# SÓ in-app (como o ParceriaLeadNotifier): o volume vai para o centro/dashboard
# da gestão, sem espalhar e-mail/push por fora. Sem CATEGORIA porque não há
# canal externo a gatear.
class IntencaoCompraNotifier < ApplicationNotifier
  def entrega_externa? = false

  def titulo = "Nova intenção de compra"

  def mensagem
    comprador = record&.comprador&.name || "Alguém"
    itens = record&.itens&.sum(&:quantidade) || 0
    contato = record&.contato.presence
    base = "#{comprador} quer #{itens} #{'item'.pluralize(itens)} (retirada)."
    contato ? "#{base} Contato: #{contato}." : base
  end

  def url = "/admin/pedidos"
end
