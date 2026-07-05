class CreateProjetoTecnologias < ActiveRecord::Migration[8.1]
  def change
    # Sem timestamps: junção pura, como no DDL.
    create_table :projeto_tecnologias do |t|
      # índice avulso de projeto_id coberto pelo único composto abaixo
      t.references :projeto, null: false, index: false,
                             foreign_key: { on_delete: :cascade }
      t.references :tecnologia, null: false, foreign_key: { on_delete: :cascade }
    end

    add_index :projeto_tecnologias, [ :projeto_id, :tecnologia_id ], unique: true
  end
end
