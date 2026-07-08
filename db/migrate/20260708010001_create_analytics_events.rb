class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :anonymous_id
      t.string :nome, null: false
      t.string :rota
      t.string :referrer
      t.datetime :ocorrido_em, null: false
      t.jsonb :metadata
      # insert-only: gravado em lote pelo worker, nunca editado (o DDL só tem created_at)
      t.datetime :created_at, null: false
    end

    add_index :analytics_events, :ocorrido_em
    add_index :analytics_events, :nome
  end
end
