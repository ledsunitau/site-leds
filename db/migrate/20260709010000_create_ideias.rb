class CreateIdeias < ActiveRecord::Migration[8.1]
  def change
    create_table :ideias do |t|
      # autor: qualquer user logado (RN-01, a comunidade propõe) — opcional,
      # a ideia sobrevive ao autor apagado
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :tipo, null: false
      t.string :titulo, null: false
      t.text :descricao
      t.string :status, null: false, default: "pendente"
      # revisor é um Member (RF-IDE-04); sem índice avulso, como created_by em acoes
      t.bigint :reviewed_by
      t.datetime :reviewed_at
      t.timestamps
    end

    add_foreign_key :ideias, :members, column: :reviewed_by, on_delete: :nullify
    add_index :ideias, :status
    add_index :ideias, :tipo
    add_check_constraint :ideias, "tipo IN ('projeto','pesquisa')", name: "ideias_tipo_check"
    add_check_constraint :ideias, "status IN ('pendente','aprovada','rejeitada')",
                         name: "ideias_status_check"

    # Fecha a FK cross-fase adiada na branch de ações (idealizador, RF-ACO-07).
    # to_table explícito: o inflector não pluraliza "ideia" para "ideias".
    add_reference :acoes, :ideia, index: true,
                  foreign_key: { to_table: :ideias, on_delete: :nullify }
  end
end
