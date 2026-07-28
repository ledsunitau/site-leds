# Depoimento (review) do parceiro para a landing pública (RF-PAR). Texto curto
# + autor (ex.: "Maria, CEO da X"). A seção de reviews some se ninguém tiver.
class AddDepoimentoAosParceiros < ActiveRecord::Migration[8.1]
  def change
    add_column :parceiros, :depoimento, :text
    add_column :parceiros, :depoimento_autor, :string
  end
end
