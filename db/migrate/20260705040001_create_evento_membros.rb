class CreateEventoMembros < ActiveRecord::Migration[8.1]
  def change
    create_table :evento_membros do |t|
      # índice avulso de evento_id coberto pelo único composto abaixo
      t.references :evento, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :member, null: false, foreign_key: { on_delete: :cascade }
      t.string :papel, null: false

      t.timestamps
    end

    add_index :evento_membros, [ :evento_id, :member_id, :papel ], unique: true
    add_check_constraint :evento_membros, "papel IN ('organizador','participante')",
                         name: "evento_membros_papel_check"
  end
end
