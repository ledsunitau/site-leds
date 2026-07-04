class CreateOauthIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_identities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :uid, null: false
      # @ público do provedor (ex.: username do Discord), exibido no perfil.
      # Desvio documentado do DDL: nenhum token OAuth é persistido, só uid+username.
      t.string :username

      t.timestamps
    end

    add_index :oauth_identities, [ :provider, :uid ], unique: true
    add_check_constraint :oauth_identities,
      "provider IN ('google','discord')",
      name: "oauth_identities_provider_check"
  end
end
