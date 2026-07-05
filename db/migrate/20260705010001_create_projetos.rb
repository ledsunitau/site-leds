class CreateProjetos < ActiveRecord::Migration[8.1]
  def change
    create_table :projetos do |t|
      t.string :link
      t.string :repo_url
      t.string :hospedagem
      t.string :situacao, null: false, default: "em_desenvolvimento"
      t.date :data_finalizacao

      t.timestamps
    end

    add_check_constraint :projetos,
      "situacao IN ('em_desenvolvimento','finalizado')",
      name: "projetos_situacao_check"
    # Coerência situação/data (card mostra "em dev" ou a data de finalização)
    add_check_constraint :projetos,
      "(situacao = 'finalizado' AND data_finalizacao IS NOT NULL) " \
      "OR (situacao = 'em_desenvolvimento' AND data_finalizacao IS NULL)",
      name: "projetos_situacao_data_check"
  end
end
