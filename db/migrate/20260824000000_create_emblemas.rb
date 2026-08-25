# Emblemas (RF-EMB): conquistas customizáveis pela gestão. Três tabelas + o
# par de colunas de "equipado" em users.
#
# As listas fechadas (efeito, criterio, origem) ganham CHECK como todo enum do
# projeto (users.role, ideias.status, pedidos.status): o enum do Rails valida na
# aplicação, o CHECK impede que console/SQL gravem um valor que nenhuma tela
# saberia renderizar.
class CreateEmblemas < ActiveRecord::Migration[8.1]
  def change
    create_table :emblemas do |t|
      t.string :nome, null: false
      t.text :descricao
      # markup inline, não Active Storage: <img src> não recolore nem anima por
      # CSS, e cor + efeito por emblema é requisito. Sanitizado no model.
      t.text :icone_svg, null: false
      t.string :cor, null: false, default: "#00C55B"
      t.string :efeito, null: false, default: "nenhum"
      # NULL = não tem meta: só concessão manual ou link exclusivo
      t.string :criterio
      t.integer :meta
      # some do catálogo até o usuário desbloquear (emblema-surpresa)
      t.boolean :exclusivo, null: false, default: false
      t.string :discord_role_id
      t.boolean :ativo, null: false, default: true
      # counter_cache nativo: a raridade (% de donos) fica ordenável em SQL e
      # o catálogo não faz uma contagem por emblema
      t.integer :usuarios_count, null: false, default: 0
      t.timestamps
    end

    add_index :emblemas, :nome, unique: true
    add_check_constraint :emblemas,
                         "efeito IN ('nenhum', 'brilho', 'neon', 'arco_iris', 'pulso')",
                         name: "emblemas_efeito_check"
    add_check_constraint :emblemas,
                         "criterio IS NULL OR criterio IN ('novidades_publicadas', " \
                         "'ideias_aprovadas', 'acoes_participadas', 'comentarios', " \
                         "'avaliacoes', 'pedidos_pagos', 'dias_de_conta')",
                         name: "emblemas_criterio_check"
    # meta só faz sentido com critério, e um critério sem meta nunca dispararia
    add_check_constraint :emblemas,
                         "(criterio IS NULL AND meta IS NULL) OR (criterio IS NOT NULL AND meta > 0)",
                         name: "emblemas_criterio_meta_check"

    create_table :emblema_usuarios do |t|
      t.references :emblema, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :origem, null: false
      # quem concedeu a dedo; a concessão sobrevive ao membro apagado
      t.references :concedido_por, foreign_key: { to_table: :members, on_delete: :nullify }
      t.timestamps
    end

    add_check_constraint :emblema_usuarios,
                         "origem IN ('meta', 'concessao', 'convite')",
                         name: "emblema_usuarios_origem_check"
    # um emblema por usuário — backstop da corrida (Emblema#conceder! rescue)
    add_index :emblema_usuarios, %i[user_id emblema_id], unique: true,
              name: "index_emblema_usuarios_unicos"

    create_table :emblema_convites do |t|
      t.references :emblema, null: false, foreign_key: { on_delete: :cascade }
      t.string :token, null: false
      t.datetime :expira_em
      t.boolean :ativo, null: false, default: true
      t.integer :usos, null: false, default: 0
      t.references :criado_por, foreign_key: { to_table: :members, on_delete: :nullify }
      t.timestamps
    end

    add_index :emblema_convites, :token, unique: true

    # Equipados. Duas colunas em vez de uma flag na tabela de junção: o
    # "um de cada" sai de graça (sem índice parcial único) e o perfil carrega
    # os dois com um includes simples.
    add_reference :users, :emblema_destaque,
                  foreign_key: { to_table: :emblemas, on_delete: :nullify }
    add_reference :users, :emblema_secundario,
                  foreign_key: { to_table: :emblemas, on_delete: :nullify }
  end
end
