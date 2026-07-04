class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext"

    create_table :users do |t|
      t.citext :email, null: false
      t.string :encrypted_password, null: false, default: ""
      t.string :name, null: false
      # Papel de ACESSO lido pelo Pundit; o cargo detalhado do membro vive em mandatos.
      t.string :role, null: false, default: "comunidade"

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_check_constraint :users,
      "role IN ('comunidade','escritor','parceiro','membro','diretoria','presidencia')",
      name: "users_role_check"
  end
end
