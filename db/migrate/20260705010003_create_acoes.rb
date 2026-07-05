class CreateAcoes < ActiveRecord::Migration[8.1]
  def change
    create_table :acoes do |t|
      # Delegated type: detalhe aponta para projetos/eventos/artigos.
      # SEM FK em detalhe_id (polimórfico entre 3 tabelas — integridade na
      # aplicação, conforme a modelagem). ideia_id chega na branch de ideias.
      t.string :detalhe_type, null: false
      t.bigint :detalhe_id, null: false
      t.string :titulo, null: false
      t.text :descricao
      t.string :status, null: false, default: "rascunho"
      # coluna chama-se created_by (sem _id), como no DDL; sem índice avulso
      t.bigint :created_by

      t.timestamps
    end

    add_foreign_key :acoes, :members, column: :created_by, on_delete: :nullify

    add_index :acoes, [ :detalhe_type, :detalhe_id ], unique: true
    add_index :acoes, :status
    add_check_constraint :acoes, "detalhe_type IN ('Projeto','Evento','Artigo')",
                         name: "acoes_detalhe_type_check"
    add_check_constraint :acoes, "status IN ('rascunho','publicada','arquivada')",
                         name: "acoes_status_check"
  end
end
