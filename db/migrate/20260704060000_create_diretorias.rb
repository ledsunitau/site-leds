class CreateDiretorias < ActiveRecord::Migration[8.1]
  def change
    create_table :diretorias do |t|
      t.string :nome, null: false

      t.timestamps
    end

    add_index :diretorias, :nome, unique: true
  end
end
