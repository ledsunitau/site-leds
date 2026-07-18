class CreatePedidosEPagamentos < ActiveRecord::Migration[8.1]
  def change
    # Endereço do usuário (RF-LOJ-04, envio). A tabela nasce aqui pela FK do
    # pedido; o CRUD e o fluxo de ENVIO chegam na branch do frete (Melhor Envio).
    create_table :enderecos do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :cep, null: false, limit: 9
      t.string :logradouro, null: false
      t.string :numero
      t.string :complemento
      t.string :bairro
      t.string :cidade, null: false
      t.string :uf, null: false, limit: 2
      t.timestamps
    end

    create_table :pedidos do |t|
      t.references :user, foreign_key: { on_delete: :nullify } # sobrevive à conta apagada
      t.string :status, null: false, default: "aguardando_pagamento"
      t.string :tipo_entrega, null: false
      t.references :endereco, foreign_key: { on_delete: :nullify }
      # colunas de frete: preenchidas pela branch do frete (Melhor Envio)
      t.decimal :frete_valor, precision: 10, scale: 2
      t.string :transportadora
      t.string :servico_frete
      t.integer :prazo_estimado
      t.string :melhor_envio_ref
      t.string :rastreamento_codigo
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end

    add_index :pedidos, :status
    add_check_constraint :pedidos,
                         "status IN ('aguardando_pagamento','pago','em_producao','enviado','entregue','cancelado')",
                         name: "pedidos_status_check"
    add_check_constraint :pedidos, "tipo_entrega IN ('retirada','envio')",
                         name: "pedidos_tipo_entrega_check"
    add_check_constraint :pedidos, "frete_valor IS NULL OR frete_valor >= 0",
                         name: "pedidos_frete_valor_check"
    add_check_constraint :pedidos, "total >= 0", name: "pedidos_total_check"
    # envio exige endereço (DDL)
    add_check_constraint :pedidos, "tipo_entrega <> 'envio' OR endereco_id IS NOT NULL",
                         name: "pedidos_envio_endereco_check"

    create_table :itens_pedido do |t|
      t.references :pedido, null: false, foreign_key: { on_delete: :cascade }
      # RESTRICT: um pedido impede apagar o produto (histórico de venda)
      t.references :produto, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.references :variante, foreign_key: { on_delete: :nullify }
      t.integer :quantidade, null: false
      # snapshot do preço pago (com promoção) — promoções futuras não mexem aqui
      t.decimal :preco_unitario, precision: 10, scale: 2, null: false
      t.timestamps
    end

    add_index :itens_pedido, :produto_id
    add_check_constraint :itens_pedido, "quantidade > 0", name: "itens_pedido_quantidade_check"
    add_check_constraint :itens_pedido, "preco_unitario >= 0", name: "itens_pedido_preco_check"

    # Tentativas de pagamento (RN-12/RF-LOJ-12): SÓ gateway + gateway_ref, nunca
    # dado de cartão. Muitos por pedido (tentativas que falham e refazem).
    create_table :pagamentos do |t|
      t.references :pedido, null: false, foreign_key: { on_delete: :cascade }
      t.string :gateway, null: false
      t.string :gateway_ref # id da cobrança externa
      t.string :status, null: false, default: "pendente"
      t.decimal :valor, precision: 10, scale: 2, null: false
      t.timestamps
    end

    add_index :pagamentos, :status
    add_check_constraint :pagamentos, "status IN ('pendente','aprovado','recusado','estornado')",
                         name: "pagamentos_status_check"
    add_check_constraint :pagamentos, "valor >= 0", name: "pagamentos_valor_check"

    # Fecha a FK cross-fase adiada na branch de reservas (conversão sob demanda).
    add_foreign_key :reservas, :pedidos, column: :pedido_id, on_delete: :nullify
  end
end
