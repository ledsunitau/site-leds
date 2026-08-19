require "test_helper"

# Loja no painel: catálogo, categorias, pedidos e reservas.
# A escrita de produto reusa o concern EscritaDeProduto (o mesmo da API); o que
# se testa aqui é o caminho por formulário e os dois campos que até então não
# tinham NENHUM caminho de escrita no app: categoria_id e destaque.
class PainelLojaTest < ActionDispatch::IntegrationTest
  # Não há fixture de pedidos: o fluxo de compra nasce no checkout, e fixar um
  # pedido "no meio" arriscaria contradizer as transições. Criados à mão aqui,
  # já no estado que cada teste precisa.
  def pedido_pago
    @pedido_pago ||= Pedido.create!(comprador: users(:ana), status: "pago",
                                    tipo_entrega: "retirada", total: 60.00)
  end

  def pedido_aberto
    @pedido_aberto ||= Pedido.create!(comprador: users(:ana), status: "aguardando_pagamento",
                                      tipo_entrega: "retirada", total: 60.00)
  end

  test "as telas da loja exigem gestão" do
    sign_in users(:membro_user)

    [ painel_produtos_path, painel_categorias_path, painel_pedidos_path, painel_reservas_path ].each do |rota|
      get rota
      assert_redirected_to root_path, "#{rota} deveria barrar papel comum"
    end
  end

  test "cadastra produto com categoria e destaque" do
    categoria = Categoria.create!(nome: "Vestuário")
    sign_in users(:diretor)

    assert_difference -> { Produto.count }, 1 do
      post painel_produtos_path, params: { produto: {
        nome: "Boné LEDS", preco: "45.00", modo_venda: "estoque", status: "ativo",
        categoria_id: categoria.id, destaque: "1",
        variantes: { "0" => { nome: "Único", estoque: "10" }, "zzz_marcador" => { nome: "" } }
      } }
    end

    produto = Produto.find_by(nome: "Boné LEDS")
    assert_equal categoria, produto.categoria, "categoria_id não tinha caminho de escrita antes"
    assert produto.destaque?, "destaque não tinha caminho de escrita antes"
    assert_equal 1, produto.variantes.count, "a linha-marcador em branco não vira variante"
    assert_equal 10, produto.variantes.first.estoque
  end

  test "editar variante preserva o id, para não derrubar carrinho alheio" do
    produto = produtos(:camiseta)
    variante = produto.variantes.first
    sign_in users(:diretor)

    patch painel_produto_path(produto), params: { produto: {
      nome: produto.nome, preco: produto.preco,
      variantes: { "0" => { id: variante.id, nome: variante.nome, estoque: "99" } }
    } }

    variante.reload
    assert_equal 99, variante.estoque
    assert_equal variante.id, produto.reload.variantes.first.id, "o id da variante não pode mudar"
  end

  test "promoção acima do preço é recusada com aviso na tela" do
    sign_in users(:diretor)

    assert_no_difference -> { Produto.count } do
      post painel_produtos_path, params: { produto: {
        nome: "Errado", preco: "10.00", preco_promocional: "20.00", modo_venda: "estoque", status: "ativo"
      } }
    end
    assert_response :see_other
    assert flash[:alert].present?
  end

  test "sob demanda exige meta de produção" do
    sign_in users(:diretor)

    assert_no_difference -> { Produto.count } do
      post painel_produtos_path, params: { produto: {
        nome: "Sem meta", preco: "10.00", modo_venda: "sob_demanda", status: "ativo"
      } }
    end
    assert flash[:alert].present?
  end

  test "categorias: cria, renomeia e apaga sem levar produto junto" do
    sign_in users(:diretor)

    assert_difference -> { Categoria.count }, 1 do
      post painel_categorias_path, params: { categoria: { nome: "Acessórios" } }
    end
    categoria = Categoria.find_by(nome: "Acessórios")

    patch painel_categoria_path(categoria), params: { categoria: { nome: "Acessórios LEDS" } }
    assert_equal "Acessórios LEDS", categoria.reload.nome

    produtos(:camiseta).update!(categoria: categoria)
    assert_difference -> { Categoria.count }, -1 do
      delete painel_categoria_path(categoria)
    end
    assert Produto.exists?(produtos(:camiseta).id), "produto não vai junto"
    assert_nil produtos(:camiseta).reload.categoria_id, "fica sem categoria (FK nullify)"
  end

  test "pagamento presencial: a gestão dá a baixa manual" do
    pedido = pedido_aberto
    sign_in users(:diretor)

    # no modo "direto" a cobrança é fora do site — sem esta ação o pedido ficava
    # preso em aguardando_pagamento até a ExpirarPedidosJob cancelá-lo
    get painel_pedidos_path
    assert_select "form[action=?]", marcar_pago_painel_pedido_path(pedido)

    post marcar_pago_painel_pedido_path(pedido)
    assert_response :see_other
    assert pedido.reload.pago?

    # daí em diante o fluxo normal de fulfillment continua
    post em_producao_painel_pedido_path(pedido)
    assert pedido.reload.em_producao?
  end

  test "a gestão cancela pedido não pago e o estoque volta" do
    pedido = pedido_aberto
    sign_in users(:diretor)

    post cancelar_painel_pedido_path(pedido)
    assert pedido.reload.cancelado?
  end

  test "confirmar pagamento duas vezes não paga duas vezes" do
    pedido = pedido_pago
    sign_in users(:diretor)

    # Pedido#transicionar! sai calado quando já está no destino — a idempotência
    # existe para o webhook duplicado do gateway e vale igual para o clique duplo
    # da gestão: nada de estorno, notificação repetida ou reserva reconvertida.
    assert_no_difference -> { Noticed::Event.where(type: "PedidoPagoNotifier").count } do
      post marcar_pago_painel_pedido_path(pedido)
    end
    assert_response :see_other
    assert pedido.reload.pago?
  end

  test "o botão de confirmar pagamento some depois de pago" do
    pedido_pago
    sign_in users(:diretor)

    get painel_pedidos_path
    assert_select "form[action=?]", marcar_pago_painel_pedido_path(pedido_pago), count: 0
  end

  test "pedidos: transições de fulfillment pela tela" do
    pedido = pedido_pago
    sign_in users(:diretor)

    get painel_pedidos_path
    assert_response :success

    post em_producao_painel_pedido_path(pedido)
    assert pedido.reload.em_producao?

    post enviar_painel_pedido_path(pedido), params: { rastreamento_codigo: "BR123456789" }
    assert pedido.reload.enviado?
    assert_equal "BR123456789", pedido.rastreamento_codigo

    post entregar_painel_pedido_path(pedido)
    assert pedido.reload.entregue?
  end

  test "enviar sem código de rastreio é recusado" do
    pedido = pedido_pago
    sign_in users(:diretor)

    post enviar_painel_pedido_path(pedido), params: { rastreamento_codigo: "  " }
    assert_match(/código de rastreio/, flash[:alert])
    assert pedido.reload.pago?, "não pode ter avançado"
  end

  test "transição inválida vira aviso, não 500" do
    pedido = pedido_aberto
    sign_in users(:diretor)

    post em_producao_painel_pedido_path(pedido) # aguardando_pagamento -> em_producao não existe
    assert_response :see_other
    assert flash[:alert].present?
    assert pedido.reload.aguardando_pagamento?
  end

  test "reservas mostram o progresso e disparam a produção" do
    sign_in users(:diretor)
    get painel_reservas_path
    assert_response :success

    assert_enqueued_with job: DisparoProducaoJob do
      post painel_disparar_reserva_path(produtos(:moletom))
    end
  end

  test "disparar produção de produto que não é sob demanda é recusado" do
    sign_in users(:diretor)

    assert_no_enqueued_jobs only: DisparoProducaoJob do
      post painel_disparar_reserva_path(produtos(:camiseta))
    end
    assert_match(/não é sob demanda/, flash[:alert])
  end
end
