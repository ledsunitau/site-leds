# Autores de artigo: membros E coautores externos na mesma tabela —
# member_id nulo = autor externo (decisão da modelagem).
class CreateAutores < ActiveRecord::Migration[8.1]
  def change
    create_table :autores do |t|
      t.references :artigo, null: false, foreign_key: { on_delete: :cascade }
      t.references :member, foreign_key: { on_delete: :nullify }
      t.string :nome, null: false
      t.string :lattes_url
      t.integer :ordem, null: false, default: 1

      t.timestamps
    end
  end
end
