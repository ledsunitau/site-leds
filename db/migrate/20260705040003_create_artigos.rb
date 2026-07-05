class CreateArtigos < ActiveRecord::Migration[8.1]
  def change
    create_table :artigos do |t|
      t.text :abstract
      t.string :revista
      t.string :publicacao_url
      t.string :situacao, null: false, default: "em_desenvolvimento"
      t.date :data_finalizacao

      t.timestamps
    end

    add_check_constraint :artigos,
      "situacao IN ('em_desenvolvimento','finalizado')",
      name: "artigos_situacao_check"
    add_check_constraint :artigos,
      "(situacao = 'finalizado' AND data_finalizacao IS NOT NULL) " \
      "OR (situacao = 'em_desenvolvimento' AND data_finalizacao IS NULL)",
      name: "artigos_situacao_data_check"
  end
end
