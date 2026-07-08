class CreateCookieConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :cookie_consents do |t|
      # usuário opcional: cobre também o visitante anônimo (só o cookie)
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :anonymous_id
      # essenciais são sempre implícitos (RNF-04/05); só estes dois dependem do opt-in
      t.boolean :analytics, null: false, default: false
      t.boolean :marketing, null: false, default: false
      t.datetime :consented_at, null: false
      t.string :user_agent
      t.timestamps
    end

    add_index :cookie_consents, :anonymous_id
  end
end
