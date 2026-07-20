# Atualiza o rastreio dos pedidos enviados (RF-LOJ-11): consulta o Melhor Envio e,
# quando o status vira entregue, move o pedido a 'entregue' (notifica o comprador).
# Recorrente (config/recurring.yml).
class RastreioUpdateJob < ApplicationJob
  queue_as :default

  def perform
    Pedido.enviado.where.not(melhor_envio_ref: nil).find_each do |pedido|
      # ponytail: só 'delivered' é terminal aqui. Status de não-entrega (canceled/
      # returned) deixam o pedido preso em 'enviado', repolado a cada ciclo — a
      # gestão resolve à mão. Upgrade: estado terminal de exceção quando surgir volume.
      pedido.marcar_entregue! if MelhorEnvio.rastrear(pedido.melhor_envio_ref) == "delivered"
    rescue MelhorEnvio::ErroFrete, ActiveRecord::RecordInvalid
      next # ME fora do ar ou corrida de estado — tenta no próximo ciclo
    end
  end
end
