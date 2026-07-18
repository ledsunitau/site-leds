# RF-LOJ-05/07: as reservas ativas de um produto atingiram a quantidade_alvo —
# avisa os reservantes para pagar. Assíncrono: o disparo não pode segurar a
# transação da última reserva.
class DisparoProducaoJob < ApplicationJob
  queue_as :default

  def perform(produto_id)
    produto = Produto.find_by(id: produto_id)
    return if produto.nil?

    reservantes = produto.reservantes_ativos
    ProducaoDisparadaNotifier.with(record: produto).deliver(reservantes) if reservantes.any?
  end
end
