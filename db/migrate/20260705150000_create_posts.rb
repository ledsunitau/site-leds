class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :tipo, null: false
      t.string :titulo, null: false
      t.string :subtitulo
      # chamada do card (nome "caller" vem do DDL)
      t.string :caller
      t.string :status, null: false, default: "rascunho"
      # coluna chama-se approved_by (sem _id), como no DDL; sem índice avulso
      t.bigint :approved_by
      t.datetime :approved_at
      t.datetime :published_at

      t.timestamps
    end

    add_foreign_key :posts, :members, column: :approved_by, on_delete: :nullify

    add_index :posts, :status
    add_index :posts, :tipo
    add_index :posts, :published_at
    add_check_constraint :posts, "tipo IN ('noticia','blog')",
                         name: "posts_tipo_check"
    add_check_constraint :posts,
                         "status IN ('rascunho','em_aprovacao','publicado','rejeitado')",
                         name: "posts_status_check"
  end
end
