# Tabela do PaperTrail (RF-ADM-07, RF-NOV-07, RNF-09) por DDL: object e
# object_changes em jsonb (o gem detecta e serializa como JSON nativo).
class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.jsonb :object
      t.jsonb :object_changes
      t.datetime :created_at
    end

    add_index :versions, [ :item_type, :item_id ]
  end
end
