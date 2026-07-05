class CreateContribuicoes < ActiveRecord::Migration[8.1]
  def change
    create_table :contribuicoes do |t|
      # índice avulso de projeto_id coberto pelo único composto abaixo
      t.references :projeto, null: false, index: false,
                             foreign_key: { on_delete: :cascade }
      t.references :member, null: false, foreign_key: { on_delete: :cascade }
      t.string :papel, null: false

      t.timestamps
    end

    add_index :contribuicoes, [ :projeto_id, :member_id, :papel ], unique: true
    add_check_constraint :contribuicoes,
      "papel IN ('backend','frontend','ui_ux','design','infra','outro')",
      name: "contribuicoes_papel_check"
  end
end
