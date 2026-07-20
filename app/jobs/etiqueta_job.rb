# Pós-pagamento de um pedido de ENVIO (RF-LOJ-11): compra a etiqueta no Melhor
# Envio (declaração de conteúdo, sem NF), grava a referência + código de rastreio
# e move o pedido a 'enviado' (que notifica o comprador).
#
# NÃO reenfileira em falha: comprar_etiqueta DEBITA saldo (cart→checkout) e não é
# idempotente — re-tentar compraria uma 2ª etiqueta. Se falhar (ex.: sem
# credenciais), descarta e o pedido fica 'pago' para a gestão despachar manual
# (Admin#enviar). ponytail: quando a integração real entrar, tornar o fluxo
# retomável (persistir o ref logo após o cart) e então reativar o retry.
class EtiquetaJob < ApplicationJob
  queue_as :default
  discard_on MelhorEnvio::ErroFrete

  def perform(pedido_id)
    pedido = Pedido.find_by(id: pedido_id)
    # aceita em_producao também: a gestão pode ter avançado o pedido antes do job
    return unless pedido&.envio? && (pedido.pago? || pedido.em_producao?)

    etiqueta = MelhorEnvio.comprar_etiqueta(pedido)
    pedido.marcar_enviado!(etiqueta[:codigo], ref: etiqueta[:ref])
  end
end
