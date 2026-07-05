class CreateApresentacoes < ActiveRecord::Migration[8.1]
  def change
    create_table :apresentacoes do |t|
      # índice avulso de artigo_id coberto pelo único composto abaixo
      t.references :artigo, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :congresso, null: false, foreign_key: { on_delete: :restrict }
      t.integer :ano

      t.timestamps
    end

    add_index :apresentacoes, [ :artigo_id, :congresso_id, :ano ], unique: true
  end
end
