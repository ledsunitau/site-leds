# Emblemas escalonáveis, elo e emblema por compra (RF-EMB parte 2).
#
# Migração NOVA em vez de editar a CreateEmblemas: o banco de dev já rodou
# aquela, e em base zerada o Rails 8 restaura do structure.sql em vez de
# reexecutar migrações — reeditar a original passaria despercebido.
class EmblemasEscalonaveis < ActiveRecord::Migration[8.1]
  def up
    catalogo_de_ranks
    niveis_por_emblema
    conquistas
    elos
    colunas_novas
    backfill_conquistas
  end

  def down
    remove_reference :users, :elo, foreign_key: true
    remove_column :users, :pontos_emblemas

    add_column :emblema_usuarios, :origem, :string
    add_reference :emblema_usuarios, :concedido_por,
                  foreign_key: { to_table: :members, on_delete: :nullify }
    # devolve para a linha do usuário a origem da PRIMEIRA conquista (era o que
    # a coluna guardava antes de as conquistas existirem)
    execute <<~SQL
      UPDATE emblema_usuarios eu SET origem = c.origem, concedido_por_id = c.concedido_por_id
      FROM (SELECT DISTINCT ON (emblema_usuario_id) emblema_usuario_id, origem, concedido_por_id
            FROM emblema_conquistas ORDER BY emblema_usuario_id, ocorrido_em) c
      WHERE c.emblema_usuario_id = eu.id
    SQL
    change_column_null :emblema_usuarios, :origem, false
    add_check_constraint :emblema_usuarios, "origem IN ('meta', 'concessao', 'convite')",
                         name: "emblema_usuarios_origem_check"
    remove_reference :emblema_usuarios, :nivel, foreign_key: { to_table: :emblema_niveis }
    remove_column :emblema_usuarios, :conquistas_count

    remove_column :emblema_convites, :usos_max
    remove_column :emblema_convites, :descricao

    # o CHECK de criterio/meta menciona `tipo`, então tem de sair ANTES da
    # coluna — dropar a coluna primeiro o levaria junto e o remove falharia
    remove_check_constraint :emblemas, name: "emblemas_criterio_meta_check"
    remove_reference :emblemas, :produto, foreign_key: true
    remove_column :emblemas, :limite_donos
    remove_column :emblemas, :peso
    remove_column :emblemas, :tipo
    add_check_constraint :emblemas,
                         "(criterio IS NULL AND meta IS NULL) OR (criterio IS NOT NULL AND meta > 0)",
                         name: "emblemas_criterio_meta_check"

    drop_table :elos
    drop_table :emblema_conquistas
    drop_table :emblema_niveis
    drop_table :emblema_ranks
  end

  private

  # Bronze, Prata, Ouro… definidos UMA vez e reusados por todo emblema: mudar a
  # cor do ouro muda em todos, e "Ouro" não sai de tom diferente em cada um.
  def catalogo_de_ranks
    create_table :emblema_ranks do |t|
      t.string :nome, null: false
      t.string :cor, null: false, default: "#CD7F32"
      t.string :efeito, null: false, default: "nenhum"
      # multiplicador dos pontos do elo (bronze 1, ouro 6…)
      t.integer :peso, null: false, default: 1
      t.integer :ordem, null: false
      t.timestamps
    end

    add_index :emblema_ranks, :nome, unique: true
    add_index :emblema_ranks, :ordem, unique: true
    add_check_constraint :emblema_ranks,
                         "efeito IN ('nenhum', 'brilho', 'neon', 'arco_iris', 'pulso')",
                         name: "emblema_ranks_efeito_check"
    add_check_constraint :emblema_ranks, "peso > 0", name: "emblema_ranks_peso_check"
  end

  # O degrau: "neste emblema, o rank Ouro começa em 4".
  def niveis_por_emblema
    create_table :emblema_niveis do |t|
      t.references :emblema, null: false, foreign_key: { on_delete: :cascade }
      # restrict: rank em uso por algum emblema não pode sumir do catálogo
      t.references :rank, null: false,
                   foreign_key: { to_table: :emblema_ranks, on_delete: :restrict }
      t.integer :limiar, null: false
      t.string :discord_role_id
      t.timestamps
    end

    add_check_constraint :emblema_niveis, "limiar > 0", name: "emblema_niveis_limiar_check"
    add_index :emblema_niveis, %i[emblema_id rank_id], unique: true,
              name: "index_emblema_niveis_por_rank"
    # dois ranks no mesmo número seriam ambíguos: qual deles a pessoa alcançou?
    add_index :emblema_niveis, %i[emblema_id limiar], unique: true,
              name: "index_emblema_niveis_por_limiar"
  end

  # Cada cumprimento vira um registro: é o que o hover do perfil lista
  # ("Maratona SBC 2026 · 14 mai 2026") e o que faz o rank subir.
  def conquistas
    create_table :emblema_conquistas do |t|
      t.references :emblema_usuario, null: false, foreign_key: { on_delete: :cascade }
      t.string :descricao
      t.string :origem, null: false
      t.references :convite, foreign_key: { to_table: :emblema_convites, on_delete: :nullify }
      t.references :concedido_por, foreign_key: { to_table: :members, on_delete: :nullify }
      t.references :pedido, foreign_key: { on_delete: :nullify }
      # separado de created_at: a gestão registra evento retroativo ("a maratona
      # do ano passado"), e é este campo que sustenta exclusividade por data
      t.datetime :ocorrido_em, null: false
      t.timestamps
    end

    add_check_constraint :emblema_conquistas,
                         "origem IN ('meta', 'concessao', 'convite', 'compra')",
                         name: "emblema_conquistas_origem_check"
    add_index :emblema_conquistas, :ocorrido_em
  end

  # Degraus de pontuação. O elo FINAL é o de maior pontos_minimos — não precisa
  # de coluna para marcá-lo.
  def elos
    create_table :elos do |t|
      t.string :nome, null: false
      t.string :cor, null: false, default: "#00C55B"
      t.string :efeito, null: false, default: "nenhum"
      t.text :icone_svg
      t.integer :pontos_minimos, null: false
      t.string :discord_role_id
      t.timestamps
    end

    add_index :elos, :nome, unique: true
    add_index :elos, :pontos_minimos, unique: true
    add_check_constraint :elos,
                         "efeito IN ('nenhum', 'brilho', 'neon', 'arco_iris', 'pulso')",
                         name: "elos_efeito_check"
    add_check_constraint :elos, "pontos_minimos >= 0", name: "elos_pontos_check"
  end

  def colunas_novas
    add_column :emblemas, :tipo, :string, null: false, default: "unico"
    add_column :emblemas, :peso, :integer, null: false, default: 1
    add_column :emblemas, :limite_donos, :integer
    # "os 10 primeiros que comprarem": concede na confirmação do pagamento
    add_reference :emblemas, :produto, foreign_key: { on_delete: :nullify }

    add_check_constraint :emblemas, "tipo IN ('unico', 'escalonavel')",
                         name: "emblemas_tipo_check"
    add_check_constraint :emblemas, "peso > 0", name: "emblemas_peso_check"
    add_check_constraint :emblemas, "limite_donos IS NULL OR limite_donos > 0",
                         name: "emblemas_limite_donos_check"

    # Escalonável não usa `meta` — os limiares vivem em emblema_niveis. O CHECK
    # antigo exigia o par (criterio, meta) casado, o que barraria escalonável
    # com critério e sem meta.
    remove_check_constraint :emblemas, name: "emblemas_criterio_meta_check"
    add_check_constraint :emblemas, <<~SQL.squish, name: "emblemas_criterio_meta_check"
      (tipo = 'escalonavel' AND meta IS NULL)
      OR (tipo = 'unico' AND ((criterio IS NULL AND meta IS NULL)
                              OR (criterio IS NOT NULL AND meta > 0)))
    SQL

    add_column :emblema_convites, :usos_max, :integer
    add_column :emblema_convites, :descricao, :string
    add_check_constraint :emblema_convites, "usos_max IS NULL OR usos_max > 0",
                         name: "emblema_convites_usos_max_check"

    add_reference :emblema_usuarios, :nivel,
                  foreign_key: { to_table: :emblema_niveis, on_delete: :nullify }
    add_column :emblema_usuarios, :conquistas_count, :integer, null: false, default: 0

    add_column :users, :pontos_emblemas, :integer, null: false, default: 0
    add_reference :users, :elo, foreign_key: { on_delete: :nullify }
    # ordenação do ranking; DESC porque a consulta é sempre "quem tem mais"
    add_index :users, :pontos_emblemas, order: { pontos_emblemas: :desc }
  end

  # origem/concedido_por saem de emblema_usuarios e passam a viver em cada
  # conquista — manter os dois lugares seria duplicação a sincronizar. Backfill
  # antes de derrubar as colunas: toda linha existente vira uma conquista.
  def backfill_conquistas
    execute <<~SQL
      INSERT INTO emblema_conquistas
        (emblema_usuario_id, origem, concedido_por_id, ocorrido_em, created_at, updated_at)
      SELECT id, origem, concedido_por_id, created_at, created_at, created_at
      FROM emblema_usuarios
    SQL
    execute "UPDATE emblema_usuarios SET conquistas_count = 1"

    remove_reference :emblema_usuarios, :concedido_por, foreign_key: { to_table: :members }
    # o CHECK de origem cai junto com a coluna: no Postgres, DROP COLUMN leva as
    # constraints que dependem dela. Removê-lo explicitamente depois é erro.
    remove_column :emblema_usuarios, :origem
  end
end
