class CreateMandatos < ActiveRecord::Migration[8.1]
  def change
    create_table :mandatos do |t|
      # index: false — o índice composto (member_id, gestao_id) abaixo já
      # cobre buscas por member_id; o DDL não tem índice avulso aqui.
      t.references :member, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :gestao, null: false, foreign_key: { to_table: :gestoes, on_delete: :restrict }
      t.references :diretoria, foreign_key: { to_table: :diretorias, on_delete: :nullify }
      t.string :cargo, null: false

      t.timestamps
    end

    add_index :mandatos, [ :member_id, :gestao_id ], unique: true
    add_index :mandatos, :cargo
    add_check_constraint :mandatos,
      "cargo IN ('presidente','vice','diretor','orientador','membro')",
      name: "mandatos_cargo_check"
  end
end
