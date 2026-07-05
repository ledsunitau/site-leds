class CreateEventos < ActiveRecord::Migration[8.1]
  def change
    create_table :eventos do |t|
      t.string :local
      # estado (vai acontecer / acontecendo / já aconteceu) é DERIVADO das
      # datas na aplicação — não é coluna (decisão da modelagem)
      t.datetime :data_inicio, null: false
      t.datetime :data_fim

      t.timestamps
    end

    add_index :eventos, :data_inicio # consultas do calendário
    add_check_constraint :eventos, "data_fim IS NULL OR data_fim >= data_inicio",
                         name: "eventos_datas_check"
  end
end
