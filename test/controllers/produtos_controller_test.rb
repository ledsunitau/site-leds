require "test_helper"

# RF-LOJ-01/03/09/10 + RN-17: catálogo da loja.
class ProdutosControllerTest < ActionDispatch::IntegrationTest
  # --- RN-17: a loja é o único canto do site onde LER exige login ---

  test "anônimo não vê o catálogo nem o produto (padrão exclusivo da loja)" do
    get produtos_path
    assert_response :redirect

    get produto_path(produtos(:camiseta))
    assert_response :redirect
  end

  test "qualquer usuário logado vê a vitrine (só ativos)" do
    sign_in users(:ana) # comunidade: compra, não cadastra
    get produtos_path

    assert_response :success
    nomes = response.parsed_body["produtos"].map { |p| p["nome"] }
    assert_equal [ "Camiseta LEDS", "Moletom LEDS" ], nomes.sort
    assert_not_includes nomes, "Caneca antiga", "indisponível fica fora da vitrine"
  end

  test "quem cadastra filtra por status; o cliente não" do
    sign_in users(:ana)
    get produtos_path(status: "indisponivel")
    nomes = response.parsed_body["produtos"].map { |p| p["nome"] }
    assert_not_includes nomes, "Caneca antiga", "filtro ignorado para quem só compra"

    sign_in users(:membro_user)
    get produtos_path(status: "indisponivel")
    assert_equal [ "Caneca antiga" ], response.parsed_body["produtos"].map { |p| p["nome"] }
  end

  test "filtro por modo de venda" do
    sign_in users(:ana)
    get produtos_path(modo_venda: "sob_demanda")
    assert_equal [ "Moletom LEDS" ], response.parsed_body["produtos"].map { |p| p["nome"] }
  end

  test "show traz variantes e o preço vigente" do
    sign_in users(:ana)
    get produto_path(produtos(:camiseta))

    body = response.parsed_body
    # Contrato de dinheiro: numeric(10,2) vira BigDecimal e o Rails serializa
    # como STRING de propósito (float perderia precisão). O cliente formata.
    # Fixado aqui: sem isso, trocar para número JSON quebraria o cliente com a
    # suíte verde (um .to_f na asserção passa dos dois jeitos).
    assert_equal "49.9", body["preco_atual"], "promoção manda (RF-LOJ-10)"
    assert_equal "60.0", body["preco"]
    assert_equal %w[G M], body["variantes"].map { |v| v["nome"] }.sort
  end

  # --- RN-13 / matriz: quem cadastra ---

  test "comunidade, escritor e parceiro compram mas não cadastram" do
    %i[ana escritor_user parceiro_user].each do |quem|
      sign_in users(quem)
      post produtos_path, params: { produto: { nome: "Pirata", preco: 1 } }
      assert_response :forbidden, "#{quem} não cadastra produto (matriz)"

      get produtos_path
      assert_response :success, "#{quem} compra, então vê a vitrine"
    end
  end

  test "produto indisponível também não é servido por id (index não pode ser furado)" do
    sign_in users(:ana)
    get produto_path(produtos(:caneca_antiga))
    assert_response :forbidden

    sign_in users(:membro_user)
    get produto_path(produtos(:caneca_antiga))
    assert_response :success, "quem cadastra segue enxergando para operar"
  end

  test "membro cadastra produto com variantes e fica auditado" do
    sign_in users(:membro_user)

    assert_difference [ "Produto.count", "Variante.count" ], 1 do
      post produtos_path, params: {
        produto: {
          nome: "Boné LEDS", preco: "40.00", modo_venda: "estoque",
          variantes: [ { nome: "Único", sku: "BON-U", estoque: "5" } ]
        }
      }
    end
    assert_response :created

    produto = Produto.find(response.parsed_body["id"])
    assert_equal members(:membro_comum), produto.criador
    assert produto.versions.any?, "RF-LOJ-09: cadastro auditado"
  end

  test "sob demanda sem quantidade_alvo é 422" do
    sign_in users(:membro_user)
    post produtos_path, params: { produto: { nome: "X", preco: "10", modo_venda: "sob_demanda" } }
    assert_response :unprocessable_entity
  end

  test "editar a lista de variantes preserva o id das mantidas (carrinhos futuros apontam para ele)" do
    sign_in users(:membro_user)
    id_m = variantes(:camiseta_m).id

    # manda M (com id) e remove G
    assert_difference "Variante.count", -1 do
      patch produto_path(produtos(:camiseta)), params: {
        produto: { variantes: [ { id: id_m, nome: "M", sku: "CAM-M", estoque: "3" } ] }
      }
    end
    assert_response :success

    variantes = produtos(:camiseta).reload.variantes
    assert_equal [ "M" ], variantes.map(&:nome)
    assert_equal id_m, variantes.first.id, "o id NÃO pode trocar numa edição de estoque"
    assert_equal 3, variantes.first.estoque
  end

  test "remoção de variante é auditada (RN-13 vale para a variante, não só o produto)" do
    sign_in users(:membro_user)

    # sem esta asserção, trocar destroy_all por delete_all mataria o rastro do
    # inventário com a suíte verde
    assert_difference "PaperTrail::Version.where(item_type: 'Variante', event: 'destroy').count", 1 do
      patch produto_path(produtos(:camiseta)), params: {
        produto: { variantes: [ { id: variantes(:camiseta_m).id, nome: "M", estoque: "3" } ] }
      }
    end

    # e a edição da mantida vira version de update (o diff do estoque)
    assert Variante.find(variantes(:camiseta_m).id).versions.any? { |v| v.event == "update" }
  end

  test "variante nova (sem id) é criada junto das mantidas" do
    sign_in users(:membro_user)

    assert_difference "Variante.count", 1 do
      patch produto_path(produtos(:camiseta)), params: {
        produto: { variantes: [
          { id: variantes(:camiseta_m).id, nome: "M", sku: "CAM-M", estoque: "1" },
          { id: variantes(:camiseta_g).id, nome: "G", sku: "CAM-G", estoque: "1" },
          { nome: "GG", sku: "CAM-GG", estoque: "2" }
        ] }
      }
    end
    assert_response :success
    assert_equal %w[G GG M], produtos(:camiseta).reload.variantes.map(&:nome).sort
  end

  test "lista de variantes malformada é 422, não apaga tudo em silêncio" do
    sign_in users(:membro_user)

    assert_no_difference "Variante.count" do
      patch produto_path(produtos(:camiseta)), params: {
        produto: { variantes: %w[M G] } # nomes soltos em vez de objetos
      }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "lista vazia esvazia de propósito" do
    sign_in users(:membro_user)

    assert_difference "Variante.count", -2 do
      patch produto_path(produtos(:camiseta)), params: { produto: { variantes: [] } }, as: :json
    end
    assert_response :success
    assert_empty produtos(:camiseta).reload.variantes
  end

  test "variantes ausentes no payload não mexem na lista" do
    sign_in users(:membro_user)

    assert_no_difference "Variante.count" do
      patch produto_path(produtos(:camiseta)), params: { produto: { nome: "Camiseta LEDS v2" } }
    end
    assert_response :success
    assert_equal "Camiseta LEDS v2", produtos(:camiseta).reload.nome
  end

  test "marcar indisponível tira da vitrine (RF-LOJ-08)" do
    sign_in users(:membro_user)
    patch produto_path(produtos(:camiseta)), params: { produto: { status: "indisponivel" } }
    assert_response :success

    sign_in users(:ana)
    get produtos_path
    assert_not_includes response.parsed_body["produtos"].map { |p| p["nome"] }, "Camiseta LEDS"
  end
end
