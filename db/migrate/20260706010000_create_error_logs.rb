class CreateErrorLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :error_logs do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.datetime :occurred_at, null: false
      t.string :rota
      t.string :componente
      t.string :acao_tentada
      # já chega MASCARADO da aplicação (RN-16) — nunca gravar params crus
      t.jsonb :input_payload
      t.string :error_class
      t.text :error_message
      t.text :backtrace
      t.string :severidade, null: false, default: "error"
      t.string :ambiente
      t.string :user_agent
      # o DDL só tem created_at (log é insert-only, nunca é editado)
      t.datetime :created_at, null: false
    end

    add_index :error_logs, :occurred_at
    add_index :error_logs, :severidade
    add_index :error_logs, :rota
    add_check_constraint :error_logs,
                         "severidade IN ('info','warning','error','fatal')",
                         name: "error_logs_severidade_check"
  end
end
