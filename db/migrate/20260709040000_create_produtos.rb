class CreateProdutos < ActiveRecord::Migration[8.1]
  def change
    create_table :produtos do |t|
      t.string :nome, null: false
      t.text :descricao
      # RF-LOJ-03/RN-09: modo por produto e reversível. estoque → disponibilidade
      # vem de variantes.estoque; sob_demanda → de quantidade_alvo (a meta que
      # dispara a produção, RF-LOJ-05).
      t.string :modo_venda, null: false, default: "estoque"
      t.decimal :preco, precision: 10, scale: 2, null: false
      t.decimal :preco_promocional, precision: 10, scale: 2 # RF-LOJ-10
      # RF-LOJ-08: indisponivel tira dos carrinhos (trigger chega na branch do
      # carrinho, quando itens_carrinho/reservas existirem)
      t.string :status, null: false, default: "ativo"
      t.integer :quantidade_alvo
      # quem cadastrou é um Member; sem índice avulso, como created_by em acoes
      t.bigint :created_by
      t.timestamps
    end

    add_foreign_key :produtos, :members, column: :created_by, on_delete: :nullify
    add_index :produtos, :status
    add_index :produtos, :modo_venda
    add_check_constraint :produtos, "modo_venda IN ('estoque','sob_demanda')",
                         name: "produtos_modo_venda_check"
    add_check_constraint :produtos, "status IN ('ativo','indisponivel')",
                         name: "produtos_status_check"
    add_check_constraint :produtos, "preco >= 0", name: "produtos_preco_check"
    add_check_constraint :produtos, "preco_promocional IS NULL OR preco_promocional >= 0",
                         name: "produtos_preco_promocional_check"
    add_check_constraint :produtos, "quantidade_alvo IS NULL OR quantidade_alvo > 0",
                         name: "produtos_quantidade_alvo_check"

    create_table :variantes do |t|
      t.references :produto, null: false, foreign_key: { on_delete: :cascade }
      t.string :nome, null: false
      t.string :sku
      t.integer :estoque, null: false, default: 0
      t.timestamps
    end

    # único só quando preenchido: variante sem SKU é permitida (DDL)
    add_index :variantes, :sku, unique: true, where: "sku IS NOT NULL"
    add_check_constraint :variantes, "estoque >= 0", name: "variantes_estoque_check"
  end
end
