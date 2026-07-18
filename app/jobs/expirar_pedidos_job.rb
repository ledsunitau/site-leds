# Libera o estoque preso em pedidos abandonados (RF-LOJ-04): cancela os que
# ficaram em aguardando_pagamento além da janela. cancelar! devolve o estoque
# dos itens de estoque. Sem isso, um pedido nunca pago segura o estoque para
# sempre — um cliente que fecha a aba tiraria o produto de todo mundo.
# Recorrente (config/recurring.yml).
class ExpirarPedidosJob < ApplicationJob
  queue_as :default

  JANELA = 1.hour

  def perform
    Pedido.aguardando_pagamento.where(created_at: ..JANELA.ago).find_each do |pedido|
      pedido.cancelar!
    rescue ActiveRecord::RecordInvalid
      next # correu com um pagamento/cancelamento — segue
    end
  end
end
