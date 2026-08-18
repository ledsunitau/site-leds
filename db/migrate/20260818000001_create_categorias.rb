# Categoria de produto (RF-LOJ-01): agrupa a vitrine para o filtro lateral do
# catálogo expandido (#LOJA2). Lookup simples, editável pela gestão no futuro.
class CreateCategorias < ActiveRecord::Migration[8.1]
  def change
    create_table :categorias do |t|
      t.string :nome, null: false
      t.timestamps
    end

    add_index :categorias, :nome, unique: true
  end
end
