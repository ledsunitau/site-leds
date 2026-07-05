# Congressos reutilizáveis (CICTED etc.) onde artigos são apresentados.
class CreateCongressos < ActiveRecord::Migration[8.1]
  def change
    create_table :congressos do |t|
      t.string :nome, null: false

      t.timestamps
    end

    add_index :congressos, :nome, unique: true
  end
end
