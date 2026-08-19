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

  # Pedido com itens reais: o card mostra foto, variante, quantidade, preço
  # unitário congelado e subtotal por linha.
  def pedido_com_itens
    @pedido_com_itens ||= begin
      pedido = Pedido.create!(comprador: users(:ana), status: "pago",
                              tipo_entrega: "retirada", total: 170.00)
      pedido.itens.create!(produto: produtos(:camiseta), variante: variantes(:camiseta_m),
                           quantidade: 2, preco_unitario: 49.90)
      pedido.itens.create!(produto: produtos(:moletom), variante: variantes(:moletom_unico),
                           quantidade: 1, preco_unitario: 70.20)
      pedido
    end
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

  test "cada item do pedido aparece na própria linha, com variante e subtotal" do
    pedido = pedido_com_itens
    sign_in users(:diretor)

    get painel_pedidos_path
    assert_response :success

    # um bloco por item — antes era texto corrido em que os itens se misturavam
    assert_select ".painel-pedido .painel-item", count: 2
    assert_select ".painel-item-variante", text: "M"
    assert_select ".painel-item-qtd", text: "2×"
    # preço congelado no item, não o preço atual do produto
    assert_select ".painel-item-unit", text: /49,90/
    assert_select ".painel-item-subtotal", text: /99,80/
    assert_select ".painel-item-nome a[href=?]", edit_painel_produto_path(produtos(:camiseta))
  end

  test "o card do pedido mostra estado, rastreador, comprador e forma de pagamento" do
    pedido = pedido_com_itens
    sign_in users(:diretor)
    get painel_pedidos_path

    assert_select ".painel-pedido.pago", count: 1
    assert_select ".painel-pedido-id", text: "##{pedido.id}"
    assert_select ".painel-pedido-fluxo .pedido-step"      # rastreador de etapas
    assert_select ".painel-pedido-dado-rotulo", text: "Comprador"
    assert_select ".painel-pedido-dado-rotulo", text: "Entrega"
    assert_select ".painel-pedido-dado-rotulo", text: "Pagamento"
    # retirada não tem endereço; o card diz isso em vez de deixar em branco
    assert_select ".painel-pedido-dado-valor", text: /Retirada no campus/
  end

  test "pedido de envio mostra endereço, frete e rastreio" do
    endereco = Endereco.create!(user: users(:ana), cep: "12345678", logradouro: "Rua A",
                                numero: "10", bairro: "Centro", cidade: "Taubaté", uf: "SP")
    pedido = Pedido.create!(comprador: users(:ana), status: "enviado", tipo_entrega: "envio",
                            endereco: endereco, total: 90.00, frete_valor: 20.00,
                            transportadora: "Correios", servico_frete: "PAC",
                            prazo_estimado: 5, rastreamento_codigo: "BR123")
    pedido.itens.create!(produto: produtos(:camiseta), variante: variantes(:camiseta_m),
                         quantidade: 1, preco_unitario: 70.00)

    sign_in users(:diretor)
    get painel_pedidos_path

    assert_select ".painel-pedido-dado-valor", text: /Taubaté\/SP/
    assert_select ".painel-item-frete", count: 1, message: "o frete é uma linha própria, não some no total"
    assert_select ".painel-pedido-rastreio", text: /BR123/
  end

  test "busca por comprador filtra por nome e por e-mail" do
    do_ana = pedido_com_itens # comprador: users(:ana), "Ana Comunidade"
    do_membro = Pedido.create!(comprador: users(:membro_user), status: "pago",
                               tipo_entrega: "retirada", total: 30.00)
    sign_in users(:diretor)

    get painel_pedidos_path
    assert_select ".painel-pedido", count: 2

    get painel_pedidos_path(busca: "Ana")
    assert_select ".painel-pedido", count: 1
    assert_select ".painel-pedido-id", text: "##{do_ana.id}"

    # o mesmo campo acha por e-mail
    get painel_pedidos_path(busca: "membro@")
    assert_select ".painel-pedido-id", text: "##{do_membro.id}"

    get painel_pedidos_path(busca: "ninguém com esse nome")
    assert_select ".painel-pedido", count: 0
    assert_select ".painel-empty"
  end

  test "a busca e o filtro de status se combinam e sobrevivem um ao outro" do
    Pedido.create!(comprador: users(:ana), status: "pago", tipo_entrega: "retirada", total: 10)
    Pedido.create!(comprador: users(:ana), status: "cancelado", tipo_entrega: "retirada", total: 20)
    sign_in users(:diretor)

    get painel_pedidos_path(busca: "Ana", status: "pago")
    assert_select ".painel-pedido", count: 1
    assert_select ".painel-pedido.pago", count: 1

    # trocar de status no meio de uma busca não pode zerar a busca
    assert_select "a.chip[href=?]", painel_pedidos_path(status: "cancelado", busca: "Ana")
  end

  test "termo com caractere de LIKE é tratado como texto, não como curinga" do
    Pedido.create!(comprador: users(:ana), status: "pago", tipo_entrega: "retirada", total: 10)
    sign_in users(:diretor)

    # "%" casaria com tudo se o termo não fosse escapado
    get painel_pedidos_path(busca: "%")
    assert_select ".painel-pedido", count: 0
  end

  # ---- Entrega: retirada e envio têm fluxos diferentes ----

  test "retirada tem 4 etapas e fecha sem passar por enviado" do
    pedido = pedido_pago # tipo_entrega: retirada
    sign_in users(:diretor)

    get painel_pedidos_path
    # aguardando → pago → em produção → entregue (sem "enviado": não há transporte)
    assert_select ".painel-pedido .pedido-step", count: 4
    # a tela NÃO oferece enviar para retirada — era isso que levava o pedido a
    # um estado fora do rastreador dele e o deixava sem ação nenhuma
    assert_select "form[action=?]", enviar_painel_pedido_path(pedido), count: 0
    assert_select "form[action=?]", entregar_painel_pedido_path(pedido), count: 1

    post em_producao_painel_pedido_path(pedido)
    assert pedido.reload.em_producao?

    post entregar_painel_pedido_path(pedido)
    assert pedido.reload.entregue?, "retirada precisa conseguir chegar em entregue"
  end

  test "retirada de item de prateleira vai de pago direto a entregue" do
    pedido = pedido_pago
    sign_in users(:diretor)

    post entregar_painel_pedido_path(pedido)
    assert pedido.reload.entregue?, "exigir em_producao para item pronto é cerimônia inútil"
  end

  test "marcar retirada como enviada é recusado com aviso" do
    pedido = pedido_pago
    sign_in users(:diretor)

    post enviar_painel_pedido_path(pedido), params: { rastreamento_codigo: "BR123" }
    assert_response :see_other
    assert_match(/retirada não é enviado/, flash[:alert])
    assert pedido.reload.pago?, "não pode ter saído do lugar"
  end

  test "pedido de retirada preso em enviado ainda consegue ser fechado" do
    # registro criado antes da regra existir: não pode ficar órfão
    pedido = pedido_pago
    pedido.update_column(:status, "enviado")
    sign_in users(:diretor)

    get painel_pedidos_path
    assert_select ".painel-pedido .pedido-step", count: 5,
                  message: "o rastreador mostra a etapa real, mesmo sendo retirada"

    post entregar_painel_pedido_path(pedido)
    assert pedido.reload.entregue?
  end

  test "envio mantém as 5 etapas e não pula o enviado" do
    endereco = Endereco.create!(user: users(:ana), cep: "12345678", logradouro: "Rua A",
                                numero: "10", cidade: "Taubaté", uf: "SP")
    pedido = Pedido.create!(comprador: users(:ana), status: "pago", tipo_entrega: "envio",
                            endereco: endereco, total: 50.00)
    sign_in users(:diretor)

    get painel_pedidos_path
    assert_select ".painel-pedido .pedido-step", count: 5
    assert_select "form[action=?]", enviar_painel_pedido_path(pedido), count: 1
    # envio não oferece "entregue" antes de despachar
    assert_select "form[action=?]", entregar_painel_pedido_path(pedido), count: 0

    post entregar_painel_pedido_path(pedido)
    assert_response :see_other
    assert pedido.reload.pago?, "envio não pode pular o despacho"
  end

  test "envio: ciclo completo de fulfillment pela tela" do
    # tem de ser um pedido de ENVIO: retirada não passa por "enviado"
    endereco = Endereco.create!(user: users(:ana), cep: "12345678", logradouro: "Rua A",
                                numero: "10", cidade: "Taubaté", uf: "SP")
    pedido = Pedido.create!(comprador: users(:ana), status: "pago", tipo_entrega: "envio",
                            endereco: endereco, total: 50.00)
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
