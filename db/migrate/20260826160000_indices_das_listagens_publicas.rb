# Índices compostos para as listagens públicas paginadas (Ações, Novidades, Loja).
#
# As três filtram por status e ordenam por outra coluna, com LIMIT/OFFSET. Os
# índices que já existiam são de coluna SOLTA (index_acoes_on_status,
# index_posts_on_published_at…), então o Postgres filtrava por um e ordenava
# depois — um sort de todas as linhas publicadas para devolver 24.
#
# Com (status, coluna_de_ordem) ele lê já na ordem certa e para no LIMIT.
# A direção DESC importa: é a ordem em que as três telas leem.
class IndicesDasListagensPublicas < ActiveRecord::Migration[8.1]
  def change
    add_index :acoes, [ :status, :created_at ], order: { created_at: :desc },
              name: "index_acoes_on_status_and_created_at"
    add_index :posts, [ :status, :published_at ], order: { published_at: :desc },
              name: "index_posts_on_status_and_published_at"
    add_index :produtos, [ :status, :nome ],
              name: "index_produtos_on_status_and_nome"
  end
end
