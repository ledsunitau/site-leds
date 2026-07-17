# Item do carrinho (RF-LOJ-02). Um por (carrinho, produto, variante) — repetir
# soma quantidade em vez de duplicar (o controller faz o merge). Só produto de
# ESTOQUE e ativo entra no carrinho: sob demanda vira reserva, não item
# (regra de negócio na aplicação, modelagem C9). Não toca em variantes.estoque.
class ItemCarrinho < ApplicationRecord
  include VarianteCoerente # variante tem de existir e ser DESTE produto

  self.table_name = "itens_carrinho"

  belongs_to :carrinho
  belongs_to :produto
  belongs_to :variante, optional: true

  validates :quantidade, numericality: { greater_than: 0 }
  # SEM on: :create — o merge (re-adicionar) é um UPDATE; sem isto, um produto
  # que virou sob_demanda depois de estar no carrinho continuaria acumulando.
  validate :produto_comprável

  def card_json
    { id: id, quantidade: quantidade, variante: variante&.card_json, produto: produto.card_json }
  end

  private

  def produto_comprável
    return if produto.nil?

    errors.add(:produto, "não está disponível") unless produto.ativo?
    errors.add(:produto, "é sob demanda — use reserva, não carrinho") if produto.sob_demanda?
  end
end
