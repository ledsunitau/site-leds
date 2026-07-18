require "test_helper"

# Checkout de estoque + máquina de estados do pedido (RF-LOJ-04/07).
class CheckoutTest < ActiveSupport::TestCase
  # ana tem carrinho_da_ana com ana_camiseta: 2x camiseta_m (estoque 10, preço promo 49.90)

  test "do_carrinho cria pedido, congela preço, baixa estoque e esvazia o carrinho" do
    estoque_antes = variantes(:camiseta_m).estoque

    pedido = Checkout.do_carrinho(users(:ana))

    assert pedido.aguardando_pagamento?
    assert_equal users(:ana), pedido.comprador
    assert_equal 1, pedido.itens.size
    item = pedido.itens.first
    assert_equal 2, item.quantidade
    assert_equal BigDecimal("49.90"), item.preco_unitario, "snapshot do preço promocional (RF-LOJ-10)"
    assert_equal BigDecimal("99.80"), pedido.total
    assert_equal estoque_antes - 2, variantes(:camiseta_m).reload.estoque, "baixou o estoque"
    assert_empty users(:ana).carrinho.reload.itens, "esvaziou o carrinho"
  end

  test "preço congelado não muda com promoção futura" do
    pedido = Checkout.do_carrinho(users(:ana))
    produtos(:camiseta).update!(preco_promocional: 10.00)

    assert_equal BigDecimal("49.90"), pedido.itens.first.reload.preco_unitario, "o pedido antigo não mexe"
  end

  test "sem saldo aborta tudo (não cria pedido nem baixa estoque)" do
    variantes(:camiseta_m).update!(estoque: 1) # carrinho pede 2

    assert_no_difference [ "Pedido.count", "ItemPedido.count" ] do
      assert_raises(Checkout::SemSaldo) { Checkout.do_carrinho(users(:ana)) }
    end
    assert_equal 1, variantes(:camiseta_m).reload.estoque, "estoque intacto"
  end

  test "carrinho vazio é erro" do
    assert_raises(Checkout::Vazio) { Checkout.do_carrinho(users(:membro_user)) }
  end

  test "da_reserva cria pedido sem baixar estoque e linka a reserva" do
    reserva = reservas(:ana_moletom) # moletom sob_demanda, qtd 1, preço 150

    pedido = Checkout.da_reserva(reserva)

    assert_equal BigDecimal("150.00"), pedido.total
    assert_equal pedido, reserva.reload.pedido
    assert reserva.ativa?, "só vira convertida quando pago"
  end

  # --- máquina de estados do pedido ---

  test "marcar_pago! confirma, notifica o comprador e converte a reserva" do
    reserva = reservas(:ana_moletom)
    pedido = Checkout.da_reserva(reserva)

    pedido.marcar_pago!

    assert pedido.pago?
    assert reserva.reload.convertida?, "reserva paga vira convertida (RF-LOJ-07)"
  end

  test "marcar_pago! é idempotente (webhook reenviado não repaga)" do
    pedido = Checkout.do_carrinho(users(:ana))
    pedido.marcar_pago!
    assert_nothing_raised { pedido.marcar_pago! }
    assert pedido.pago?
  end

  test "cancelar! devolve o estoque e só vale antes de pago" do
    estoque_antes = variantes(:camiseta_m).estoque
    pedido = Checkout.do_carrinho(users(:ana))
    assert_equal estoque_antes - 2, variantes(:camiseta_m).reload.estoque

    pedido.cancelar!
    assert pedido.cancelado?
    assert_equal estoque_antes, variantes(:camiseta_m).reload.estoque, "estoque devolvido"

    pedido.update_column(:status, "pago")
    assert_raises(ActiveRecord::RecordInvalid) { pedido.cancelar! }
  end

  test "cancelar! de pedido de reserva NÃO devolve estoque (nunca baixou)" do
    reserva = reservas(:ana_moletom) # sob_demanda; da_reserva não baixa estoque
    estoque_antes = variantes(:moletom_unico).estoque
    pedido = Checkout.da_reserva(reserva)

    pedido.cancelar!
    assert pedido.cancelado?
    assert_equal estoque_antes, variantes(:moletom_unico).reload.estoque, "sob demanda não infla estoque no cancel"
  end

  # --- expiração de pedidos abandonados (libera o estoque retido) ---

  test "ExpirarPedidosJob cancela pedidos não pagos antigos e devolve o estoque" do
    estoque_antes = variantes(:camiseta_m).estoque
    pedido = Checkout.do_carrinho(users(:ana))
    assert_equal estoque_antes - 2, variantes(:camiseta_m).reload.estoque
    pedido.update_column(:created_at, 2.hours.ago)

    ExpirarPedidosJob.perform_now

    assert pedido.reload.cancelado?
    assert_equal estoque_antes, variantes(:camiseta_m).reload.estoque, "estoque liberado"
  end

  test "ExpirarPedidosJob não toca em pedido recente" do
    pedido = Checkout.do_carrinho(users(:ana))
    ExpirarPedidosJob.perform_now
    assert pedido.reload.aguardando_pagamento?, "dentro da janela não expira"
  end
end
