class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.references :user, null: false, index: { unique: true },
                          foreign_key: { on_delete: :cascade }
      t.references :padrinho, foreign_key: { to_table: :members, on_delete: :nullify }
      # RN-04: "Fundador" é tag independente do cargo (6 fundadores).
      t.boolean :founder, null: false, default: false
      t.text :bio

      t.timestamps
    end

    add_check_constraint :members, "padrinho_id IS NULL OR padrinho_id <> id",
                         name: "members_padrinho_check"
  end
end
