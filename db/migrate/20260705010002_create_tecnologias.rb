class CreateTecnologias < ActiveRecord::Migration[8.1]
  def change
    create_table :tecnologias do |t|
      # icone via Active Storage (desvio documentado: DDL tem coluna varchar)
      t.string :nome, null: false

      t.timestamps
    end

    add_index :tecnologias, :nome, unique: true
  end
end
