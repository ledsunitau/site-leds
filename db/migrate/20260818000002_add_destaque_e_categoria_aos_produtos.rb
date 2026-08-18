# Vitrine da loja (#LOJA): produtos "destaque" viram os banners do topo (a
# gestão marca no futuro painel admin) e cada produto pode ter uma categoria
# para o filtro do catálogo expandido (#LOJA2).
class AddDestaqueECategoriaAosProdutos < ActiveRecord::Migration[8.1]
  def change
    add_column :produtos, :destaque, :boolean, null: false, default: false
    # índice parcial: só os poucos destaques importam para a query dos banners
    add_index :produtos, :destaque, where: "destaque", name: "index_produtos_em_destaque"

    add_reference :produtos, :categoria, null: true,
                  foreign_key: { on_delete: :nullify }
  end
end
