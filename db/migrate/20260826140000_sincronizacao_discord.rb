# Sincronização de cargos com o Discord (RF-EMB).
#
# `discord_sincronizar` é a INTENÇÃO ("espelhar isto no Discord"), marcada pelo
# gestor; `discord_role_id` passa a ser o RESULTADO, preenchido pela
# sincronização. Antes o id era digitado à mão, o que exigia criar o cargo no
# servidor e colar o snowflake — e nada garantia que ele existisse.
#
# discord_cargos registra o que o SITE criou lá. Sem ele, quando o gestor apaga
# um emblema o discord_role_id some junto e não haveria como saber que aquele
# cargo no servidor era nosso — e "apagar o órfão" viraria apagar cargo alheio
# (moderação, bots). Só apagamos role_id que está nesta tabela.
class SincronizacaoDiscord < ActiveRecord::Migration[8.1]
  def change
    %i[emblemas emblema_niveis elos].each do |tabela|
      add_column tabela, :discord_sincronizar, :boolean, null: false, default: false
    end

    create_table :discord_cargos do |t|
      t.string :role_id, null: false
      # último nome e cor que gravamos no servidor: é o que a tela de diff
      # mostra para um cargo cuja origem já foi apagada do site
      t.string :nome
      t.string :cor
      t.timestamps
    end

    add_index :discord_cargos, :role_id, unique: true

    # quem já tinha um id colado à mão continua espelhado, sem reconfigurar
    reversible do |dir|
      dir.up do
        %w[emblemas emblema_niveis elos].each do |tabela|
          execute "UPDATE #{tabela} SET discord_sincronizar = true WHERE discord_role_id IS NOT NULL"
        end
      end
    end
  end
end
