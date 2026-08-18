# Modo "intenção de compra" (sem Mercado Pago ainda): ao finalizar, a gestão
# fecha a venda por contato direto. Guarda o contato (WhatsApp/telefone) que o
# comprador informa no checkout para a gestão conseguir chamar.
class AddContatoAoPedido < ActiveRecord::Migration[8.1]
  def change
    add_column :pedidos, :contato, :string
  end
end
