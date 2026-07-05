# Convidados EXTERNOS do evento (não membros), com suas redes sociais.
class CreateConvidados < ActiveRecord::Migration[8.1]
  def change
    create_table :convidados do |t|
      t.references :evento, null: false, foreign_key: { on_delete: :cascade }
      t.string :nome, null: false
      t.text :bio

      t.timestamps
    end

    create_table :convidado_links do |t|
      t.references :convidado, null: false, foreign_key: { on_delete: :cascade }
      t.string :rede, null: false
      t.string :url, null: false

      t.timestamps
    end
  end
end
