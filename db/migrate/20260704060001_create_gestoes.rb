class CreateGestoes < ActiveRecord::Migration[8.1]
  def change
    create_table :gestoes do |t|
      t.integer :ano_inicio, null: false
      t.integer :ano_fim, null: false

      t.timestamps
    end

    add_index :gestoes, :ano_inicio, unique: true
    add_check_constraint :gestoes, "ano_fim > ano_inicio", name: "gestoes_anos_check"
  end
end
