class CreateParceiros < ActiveRecord::Migration[8.1]
  def change
    create_table :parceiros do |t|
      # opcional: o parceiro existe como registro assim que é aceito; a área
      # própria (RF-PAR-05) só liga quando há conta vinculada
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :nome, null: false
      t.text :descricao
      t.string :site_url
      t.string :status, null: false, default: "ativo"
      t.timestamps
    end

    add_index :parceiros, :status
    add_check_constraint :parceiros, "status IN ('ativo','inativo')",
                         name: "parceiros_status_check"

    # Lead do formulário de contato (RF-PAR-03) — separado de parceiros: mantém
    # "interessado" e "parceiro efetivo" distintos (modelagem C3/C4).
    create_table :parceria_leads do |t|
      t.string :empresa, null: false
      t.string :contato_nome
      t.string :contato_email, null: false
      t.string :tipo, null: false
      t.text :descricao
      t.string :status, null: false, default: "novo"
      # preenchido quando a liga aceita o lead e ele vira parceiro
      t.references :parceiro, foreign_key: { on_delete: :nullify }
      t.timestamps
    end

    add_index :parceria_leads, :status
    add_check_constraint :parceria_leads,
                         "tipo IN ('software','pesquisa','evento','patrocinio_geral')",
                         name: "parceria_leads_tipo_check"
    add_check_constraint :parceria_leads,
                         "status IN ('novo','em_analise','convertido','recusado')",
                         name: "parceria_leads_status_check"

    # Fecha a junção cross-fase adiada na branch de ações (RF-PAR-02).
    # Sem timestamps: junção pura, como no DDL.
    create_table :acao_parceiros do |t|
      # índice avulso de acao_id coberto pelo único composto abaixo
      t.references :acao, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :parceiro, null: false, foreign_key: { on_delete: :cascade }
    end

    add_index :acao_parceiros, [ :acao_id, :parceiro_id ], unique: true
  end
end
