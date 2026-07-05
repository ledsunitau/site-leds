# Temas pré-definidos do artigo (com ícone) — análogo a tecnologias.
class CreateTemas < ActiveRecord::Migration[8.1]
  def change
    create_table :temas do |t|
      # icone via Active Storage (desvio documentado: DDL tem coluna varchar)
      t.string :nome, null: false

      t.timestamps
    end

    add_index :temas, :nome, unique: true

    # Sem timestamps: junção pura, como no DDL.
    create_table :artigo_temas do |t|
      # índice avulso de artigo_id coberto pelo único composto abaixo
      t.references :artigo, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :tema, null: false, foreign_key: { on_delete: :cascade }
    end

    add_index :artigo_temas, [ :artigo_id, :tema_id ], unique: true
  end
end
