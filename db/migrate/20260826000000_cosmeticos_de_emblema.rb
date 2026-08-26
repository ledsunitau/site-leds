# Cosmético exclusivo do emblema (RF-EMB): desbloquear o emblema desbloqueia
# uma pintura de nome + anel de avatar que é SÓ dele.
#
# Separado de `cor`/`efeito`, que continuam pintando o ÍCONE: o ícone é a
# identidade do emblema no catálogo; o cosmético é o que a pessoa veste.
#
# A exclusividade sai do GRADIENTE, com índice único — o movimento vem de uma
# lista fechada (é o motor da animação), mas dois emblemas nunca compartilham as
# mesmas cores, então nenhuma pintura se repete.
#
# A escolha de cosmético é do usuário e NÃO vem mais do emblema em destaque:
# destaque e sub-emblema passam a ser só vitrine.
class CosmeticosDeEmblema < ActiveRecord::Migration[8.1]
  def change
    add_column :emblemas, :cosmetico_gradiente, :string
    add_column :emblemas, :cosmetico_movimento, :string, null: false, default: "parado"
    add_column :emblemas, :cosmetico_velocidade, :integer, null: false, default: 4

    add_check_constraint :emblemas,
                         "cosmetico_movimento IN ('parado', 'varredura', 'fluxo', 'pulso')",
                         name: "emblemas_cosmetico_movimento_check"
    add_check_constraint :emblemas,
                         "cosmetico_velocidade BETWEEN 1 AND 30",
                         name: "emblemas_cosmetico_velocidade_check"
    # dois emblemas não podem vestir a mesma pintura. Parcial: emblema sem
    # cosmético (NULL) não disputa — nem todo emblema precisa dar um.
    add_index :emblemas, :cosmetico_gradiente, unique: true,
              where: "cosmetico_gradiente IS NOT NULL",
              name: "index_emblemas_cosmetico_unico"

    # o cosmético que a pessoa está usando; nulo = nome branco, sem anel
    add_reference :users, :emblema_cosmetico,
                  foreign_key: { to_table: :emblemas, on_delete: :nullify }

    # Semente: cada emblema que já existe ganha um gradiente derivado da própria
    # cor de ícone, para nenhum deles nascer sem cosmético (e sem colidir — a
    # cor do ícone já é o que distingue os emblemas entre si hoje).
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE emblemas SET cosmetico_gradiente = cor || ',' || cor
          WHERE cosmetico_gradiente IS NULL
            AND cor NOT IN (SELECT cor FROM emblemas GROUP BY cor HAVING count(*) > 1)
        SQL
      end
    end
  end
end
