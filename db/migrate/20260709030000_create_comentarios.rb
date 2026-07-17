class CreateComentarios < ActiveRecord::Migration[8.1]
  def change
    create_table :comentarios do |t|
      t.references :post, null: false, foreign_key: { on_delete: :cascade }
      # autor opcional: o comentário sobrevive ao usuário apagado
      t.references :user, foreign_key: { on_delete: :nullify }
      t.text :corpo, null: false
      # nasce visivel (publicado na hora); a gestão oculta/remove (RF-NOV-10).
      # Soft delete: preserva o rastro, nunca apaga a linha.
      t.string :status, null: false, default: "visivel"
      # quem moderou é um Member; sem índice avulso, como created_by em acoes
      t.bigint :moderated_by
      t.datetime :moderated_at
      t.timestamps
    end

    add_foreign_key :comentarios, :members, column: :moderated_by, on_delete: :nullify
    add_index :comentarios, :status
    add_check_constraint :comentarios, "status IN ('visivel','oculto','removido')",
                         name: "comentarios_status_check"

    # Denúncia de comentário (RF-NOV-09) → aba do dashboard (RF-ADM-05)
    create_table :denuncias do |t|
      t.references :comentario, null: false, foreign_key: { on_delete: :cascade }
      # index: false — o DDL declara índice de user em comentarios, mas NÃO em
      # denuncias (não se lista denúncia por denunciante)
      t.references :user, index: false, foreign_key: { on_delete: :nullify }
      t.string :motivo
      t.string :status, null: false, default: "pendente"
      t.bigint :resolved_by
      t.datetime :resolved_at
      t.timestamps
    end

    add_foreign_key :denuncias, :members, column: :resolved_by, on_delete: :nullify
    add_index :denuncias, :status
    add_check_constraint :denuncias, "status IN ('pendente','resolvida')",
                         name: "denuncias_status_check"
  end
end
