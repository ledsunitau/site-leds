# Item de pedido: SNAPSHOT do que foi comprado (RF-LOJ-10). preco_unitario é
# congelado na criação (preco_atual do produto na hora) — promoção futura não
# mexe em pedido antigo. Guarda variante para o estoque saber o que devolver.
class ItemPedido < ApplicationRecord
  include VarianteCoerente # variante tem de existir e ser DESTE produto

  self.table_name = "itens_pedido"

  belongs_to :pedido
  belongs_to :produto
  belongs_to :variante, optional: true

  validates :quantidade, numericality: { greater_than: 0 }
  validates :preco_unitario, numericality: { greater_than_or_equal_to: 0 }

  def subtotal = preco_unitario * quantidade

  def card_json
    {
      produto: produto.nome,
      variante: variante&.nome,
      quantidade: quantidade,
      preco_unitario: preco_unitario,
      subtotal: subtotal
    }
  end

  # Devolve ao estoque o que este item retirou (cancelamento). Só o modo estoque
  # baixa no checkout (da_reserva não toca em estoque), então só ele devolve —
  # senão um pedido de reserva cancelado inflaria estoque que nunca saiu.
  def devolver_estoque!
    return unless produto.estoque?

    variante&.increment!(:estoque, quantidade)
  end
end
