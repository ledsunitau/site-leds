class CreateCarrinhosEReservas < ActiveRecord::Migration[8.1]
  def change
    # Um carrinho por usuário (índice único em user_id).
    create_table :carrinhos do |t|
      t.references :user, null: false, index: { unique: true },
                          foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    create_table :itens_carrinho do |t|
      t.references :carrinho, null: false, foreign_key: { on_delete: :cascade }
      # produto CASCADE: o trigger de indisponível apaga o item; se o produto
      # for de fato removido, o item vai junto
      t.references :produto, null: false, foreign_key: { on_delete: :cascade }
      t.references :variante, foreign_key: { on_delete: :nullify }
      t.integer :quantidade, null: false, default: 1
      t.timestamps
    end

    # um item por (carrinho, produto, variante): repetir soma quantidade, não duplica
    add_index :itens_carrinho, %i[carrinho_id produto_id variante_id], unique: true,
              name: "index_itenscarr_on_carr_prod_var"
    add_check_constraint :itens_carrinho, "quantidade > 0", name: "itens_carrinho_quantidade_check"

    create_table :reservas do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # RESTRICT: uma reserva impede apagar o produto (histórico de demanda);
      # o caminho de retirar do ar é status=indisponivel, não delete
      t.references :produto, null: false, index: false,
                             foreign_key: { on_delete: :restrict }
      t.references :variante, foreign_key: { on_delete: :nullify }
      t.integer :quantidade, null: false, default: 1
      t.string :status, null: false, default: "ativa"
      # pedido chega na branch do checkout (FK adiada, como as outras cross-fase)
      t.bigint :pedido_id
      t.timestamps
    end

    add_index :reservas, %i[produto_id status], name: "index_reservas_on_produto_status"
    add_index :reservas, :pedido_id
    add_check_constraint :reservas, "quantidade > 0", name: "reservas_quantidade_check"
    add_check_constraint :reservas, "status IN ('ativa','cancelada','convertida')",
                         name: "reservas_status_check"

    # RN-11 (no BANCO, como o DDL): produto → indisponível limpa os carrinhos e
    # cancela as reservas ativas de uma vez. As NOTIFICAÇÕES aos reservantes são
    # da aplicação, depois (Produto#after_update_commit).
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE OR REPLACE FUNCTION trg_produto_indisponivel() RETURNS trigger AS $$
          BEGIN
            IF NEW.status = 'indisponivel' AND OLD.status IS DISTINCT FROM 'indisponivel' THEN
              DELETE FROM itens_carrinho WHERE produto_id = NEW.id;
              UPDATE reservas SET status = 'cancelada', updated_at = now()
               WHERE produto_id = NEW.id AND status = 'ativa';
            END IF;
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER produto_indisponivel_after
            AFTER UPDATE OF status ON produtos
            FOR EACH ROW EXECUTE FUNCTION trg_produto_indisponivel();
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP TRIGGER produto_indisponivel_after ON produtos;
          DROP FUNCTION trg_produto_indisponivel();
        SQL
      end
    end
  end
end
