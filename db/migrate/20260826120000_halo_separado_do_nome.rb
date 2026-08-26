# Halo e cor do nome viram escolhas INDEPENDENTES (RF-EMB): dá para usar a cor
# de um emblema no nome e o halo de outro no avatar.
#
# O rename é por clareza: com dois slots, "cosmetico" não diz mais qual dos dois
# é. Migração nova em vez de editar a anterior — ela já rodou no banco de dev, e
# em base zerada o Rails restaura do structure.sql em vez de reexecutar.
class HaloSeparadoDoNome < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :emblema_cosmetico_id, :emblema_nome_id
    add_reference :users, :emblema_halo,
                  foreign_key: { to_table: :emblemas, on_delete: :nullify }

    # quem já vestia uma pintura continua com ela nos dois slots: era o que a
    # escolha única fazia, então nada muda de aparência no dia da migração
    reversible do |dir|
      dir.up { execute "UPDATE users SET emblema_halo_id = emblema_nome_id" }
    end
  end
end
