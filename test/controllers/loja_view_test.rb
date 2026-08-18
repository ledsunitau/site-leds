require "test_helper"

# RF-LOJ: telas HTML da loja (#LOJA/#LOJA2/#LOJA3/#LOJA4), avaliações (só quem
# comprou) e os toggles de gestão (liga/desliga + modo de pagamento).
class LojaViewTest < ActionDispatch::IntegrationTest
  # --- páginas (RN-17: ver exige login) ---

  test "home da loja renderiza produtos e o carrinho flutuante" do
    sign_in users(:ana)
    get produtos_path

    assert_response :success
    assert_select "h1", "Loja"
    assert_select ".produto-card"
    assert_select ".cart-fab"
  end

  test "catálogo expandido tem sidebar, busca, cards e volta pra loja" do
    sign_in users(:ana)
    get todos_produtos_path

    assert_response :success
    assert_select ".loja-filtros"
    assert_select ".produto-card"
    assert_select "input.loja-busca"
    assert_select ".preco-slider input.preco-range", 2 # filtro de preço (2 thumbs)
    assert_select ".loja-promo-toggle input[type=checkbox]" # filtro de promoções
    assert_select "a[href=?]", produtos_path # voltar à loja
  end

  test "detalhe do produto mostra tamanhos (variantes) e seção de avaliações" do
    sign_in users(:ana)
    get produto_path(produtos(:camiseta))

    assert_response :success
    assert_select ".produto-nome", /Camiseta/
    assert_select ".tamanho-chip" # camiseta tem variantes M/G
    assert_select "#avaliacoes"
  end

  test "página do carrinho lista itens e o form de finalizar" do
    sign_in users(:ana) # tem ana_camiseta no carrinho (fixture)
    get carrinho_path

    assert_response :success
    assert_select ".carrinho-item"
    assert_select "form[action=?]", checkout_path
  end

  # --- barra de gestão só para gestão ---

  test "a barra de gestão aparece só para diretoria/presidência" do
    sign_in users(:ana)
    get produtos_path
    assert_select ".loja-gestao-bar", false, "comprador não vê controles de gestão"

    sign_in users(:diretor)
    get produtos_path
    assert_select ".loja-gestao-bar"
  end

  # --- toggle liga/desliga (RF-LOJ) ---

  test "loja desativada: comprador vê indisponível, quem opera vê o catálogo" do
    Setting.loja_ativa = false

    sign_in users(:ana)
    get produtos_path
    assert_response :service_unavailable
    assert_select ".loja-off"

    sign_in users(:membro_user) # membro da liga opera mesmo com a loja fechada
    get produtos_path
    assert_response :success
    assert_select ".produto-card"
  end

  test "toggles da loja são da gestão (Admin::BaseController)" do
    patch admin_loja_config_path, params: { loja_ativa: "false" }
    assert_response :redirect # deslogado → login

    sign_in users(:membro_user)
    patch admin_loja_config_path, params: { loja_ativa: "false" }
    assert_response :forbidden # membro não é gestão

    sign_in users(:diretor)
    patch admin_loja_config_path, params: { loja_ativa: "false" }
    assert_response :redirect
    assert_not Setting.loja_ativa?

    patch admin_loja_config_path, params: { modo_pagamento: "mercado_pago" }
    assert_equal "mercado_pago", Setting.modo_pagamento
  end

  # --- avaliações: só quem comprou, uma vez (#LOJA4) ---

  test "só quem comprou avalia, e no máximo uma vez" do
    # ana compra a camiseta (carrinho fixture → pedido pago)
    pedido = Checkout.do_carrinho(users(:ana))
    pedido.marcar_pago!

    sign_in users(:ana)
    assert_difference "Avaliacao.count", 1 do
      post produto_avaliacoes_path(produtos(:camiseta)),
           params: { avaliacao: { nota: 5, comentario: "Ótima camiseta!" } }, as: :json
    end
    assert_response :created

    # segunda vez do mesmo usuário: barrado
    assert_no_difference "Avaliacao.count" do
      post produto_avaliacoes_path(produtos(:camiseta)),
           params: { avaliacao: { nota: 3, comentario: "de novo" } }, as: :json
    end
    assert_response :unprocessable_entity

    # quem não comprou: barrado
    sign_in users(:membro_user)
    assert_no_difference "Avaliacao.count" do
      post produto_avaliacoes_path(produtos(:camiseta)),
           params: { avaliacao: { nota: 4, comentario: "sem ter comprado" } }, as: :json
    end
    assert_response :unprocessable_entity
  end
end
