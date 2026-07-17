# Carrinho da loja (RF-LOJ-02): um por usuário (índice único em user_id).
# É só uma área de espera — não mexe em estoque. O saldo ("só compra quando há
# saldo") é checado no checkout (branch do pedido), não aqui.
class Carrinho < ApplicationRecord
  belongs_to :user
  has_many :itens, class_name: "ItemCarrinho", dependent: :destroy
end
