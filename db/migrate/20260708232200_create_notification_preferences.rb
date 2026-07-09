class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      # index: false — o índice único (user_id, canal, categoria) abaixo já
      # cobre lookups por user_id pela coluna à esquerda (fiel ao DDL).
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :canal, null: false
      t.string :categoria, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    # nome curto do DDL: o default do Rails (user_id+canal+categoria) passa de
    # 63 chars e o Postgres truncaria — exceção documentada à convenção de nome.
    add_index :notification_preferences, %i[user_id canal categoria],
              unique: true, name: "index_notifpref_on_user_canal_cat"
    add_check_constraint :notification_preferences,
                         "canal IN ('in_app','email','push','discord','whatsapp')",
                         name: "notification_preferences_canal_check"
  end
end
