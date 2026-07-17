require "test_helper"

# RF-LOJ-02/05/06/08: carrinho, reservas e o gatilho de indisponível.
class LojaCarrinhoReservasTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # --- carrinho (RF-LOJ-02) ---

  test "carrinho exige login (RN-17)" do
    get carrinho_path
    assert_response :redirect
  end

  test "ver o carrinho cria o de quem ainda não tem, e mostra os itens" do
    sign_in users(:membro_user) # sem carrinho fixture
    assert_difference "Carrinho.count", 1 do
      get carrinho_path
    end
    assert_response :success
    assert_equal 0, response.parsed_body["total_itens"]
  end

  test "adicionar o mesmo produto+variante soma a quantidade, não duplica" do
    sign_in users(:ana)

    assert_no_difference "ItemCarrinho.count", "já existe ana_camiseta (qtd 2)" do
      post carrinho_itens_path, params: {
        item: { produto_id: produtos(:camiseta).id, variante_id: variantes(:camiseta_m).id, quantidade: 3 }
      }
    end
    assert_response :created
    assert_equal 5, itens_carrinho(:ana_camiseta).reload.quantidade
  end

  test "adicionar produto sem variante duas vezes soma (não duplica pela app)" do
    sign_in users(:membro_user)
    # produto de estoque sem variante: monto um na hora
    p = Produto.create!(nome: "Adesivo", preco: 5, modo_venda: "estoque", status: "ativo",
                        criador: members(:membro_comum))

    post carrinho_itens_path, params: { item: { produto_id: p.id, quantidade: 1 } }
    assert_no_difference "ItemCarrinho.count", "nil-variante: find_or_initialize acha e soma" do
      post carrinho_itens_path, params: { item: { produto_id: p.id, quantidade: 2 } }
    end
    item = users(:membro_user).carrinho.itens.find_by(produto: p)
    assert_equal 3, item.quantidade
  end

  test "quantidade a adicionar não pode ser negativa (adicionar não é diminuir)" do
    sign_in users(:ana)
    post carrinho_itens_path, params: {
      item: { produto_id: produtos(:camiseta).id, variante_id: variantes(:camiseta_m).id, quantidade: -1 }
    }
    assert_response :unprocessable_entity
    assert_equal 2, itens_carrinho(:ana_camiseta).reload.quantidade, "não mexeu"
  end

  test "variante de outro produto no item é 422 (não 500)" do
    sign_in users(:membro_user)
    post carrinho_itens_path, params: {
      # moletom_unico é variante do moletom, não da camiseta
      item: { produto_id: produtos(:camiseta).id, variante_id: variantes(:moletom_unico).id, quantidade: 1 }
    }
    assert_response :unprocessable_entity
  end

  test "não se adiciona produto sob demanda ao carrinho (é reserva)" do
    sign_in users(:ana)
    assert_no_difference "ItemCarrinho.count" do
      post carrinho_itens_path, params: { item: { produto_id: produtos(:moletom).id, quantidade: 1 } }
    end
    assert_response :unprocessable_entity
  end

  test "não se adiciona produto indisponível ao carrinho" do
    sign_in users(:ana)
    post carrinho_itens_path, params: { item: { produto_id: produtos(:caneca_antiga).id, quantidade: 1 } }
    assert_response :unprocessable_entity
  end

  test "atualizar e remover o próprio item" do
    sign_in users(:ana)
    item = itens_carrinho(:ana_camiseta)

    patch carrinho_item_path(item), params: { item: { quantidade: 1 } }
    assert_response :success
    assert_equal 1, item.reload.quantidade

    assert_difference "ItemCarrinho.count", -1 do
      delete carrinho_item_path(item)
    end
  end

  test "não mexo (update/delete) no item do carrinho de outro usuário" do
    sign_in users(:membro_user)
    post carrinho_itens_path, params: { item: { produto_id: produtos(:camiseta).id, quantidade: 1 } }
    outro_item = users(:membro_user).carrinho.itens.sole

    # cada tentativa cross-user dá 404 e ERRA — o sign_in do Devise em teste é
    # one-shot e uma request que erra não regrava a sessão, então re-sign_in
    # antes de cada uma (senão a seguinte rodaria como o último logado).
    sign_in users(:ana)
    patch carrinho_item_path(outro_item), params: { item: { quantidade: 99 } }
    assert_response :not_found

    sign_in users(:ana)
    delete carrinho_item_path(outro_item)
    assert_response :not_found

    assert_equal 1, outro_item.reload.quantidade, "intacto"
    assert ItemCarrinho.exists?(outro_item.id)
  end

  test "não cancelo a reserva de outro usuário" do
    sign_in users(:membro_user)
    post cancelar_reserva_path(reservas(:ana_moletom)) # reserva da ana
    assert_response :not_found
    assert reservas(:ana_moletom).reload.ativa?
  end

  # --- reservas (RF-LOJ-05/06) ---

  test "reservar produto sob demanda; cancelar depois" do
    sign_in users(:membro_user)

    assert_difference "Reserva.count", 1 do
      post reservas_path, params: { reserva: { produto_id: produtos(:moletom).id, quantidade: 2 } }
    end
    assert_response :created
    reserva = Reserva.last
    assert reserva.ativa?
    assert_equal users(:membro_user), reserva.user

    post cancelar_reserva_path(reserva)
    assert_response :success
    assert reserva.reload.cancelada?
  end

  test "reservar produto de estoque é 422" do
    sign_in users(:membro_user)
    assert_no_difference "Reserva.count" do
      post reservas_path, params: { reserva: { produto_id: produtos(:camiseta).id, quantidade: 1 } }
    end
    assert_response :unprocessable_entity
  end

  test "index lista só as minhas reservas" do
    sign_in users(:ana)
    get reservas_path
    ids = response.parsed_body["reservas"].map { |r| r["id"] }
    assert_equal [ reservas(:ana_moletom).id ], ids
  end

  # --- RF-LOJ-08 / RN-11: indisponível limpa e notifica ---

  test "marcar indisponível cancela ativas, limpa carrinhos e notifica SÓ os afetados" do
    item = itens_carrinho(:ana_camiseta) # produto camiseta (estoque)
    reserva_ativa = reservas(:ana_moletom) # ana, ativa
    reserva_convertida = reservas(:membro_convertida) # membro_user, convertida (paga)

    sign_in users(:diretor)

    perform_enqueued_jobs do
      patch produto_path(produtos(:camiseta)), params: { produto: { status: "indisponivel" } }
    end
    assert_not ItemCarrinho.exists?(item.id), "o trigger limpou o carrinho (RN-11)"

    perform_enqueued_jobs do
      patch produto_path(produtos(:moletom)), params: { produto: { status: "indisponivel" } }
    end
    assert reserva_ativa.reload.cancelada?, "o trigger cancelou a ativa"
    assert reserva_convertida.reload.convertida?, "mas NÃO a convertida (paga) — seletividade do trigger"

    # notifica só a reservante ativa afetada (ana), não o dono da convertida nem o ator
    assert notificado?(users(:ana), "ProdutoIndisponivelNotifier")
    assert_not notificado?(users(:membro_user), "ProdutoIndisponivelNotifier"),
               "quem tinha reserva convertida não é afetado"
    assert_not notificado?(users(:diretor), "ProdutoIndisponivelNotifier"), "nem o ator"
  end

  test "re-marcar um produto já indisponível não notifica de novo" do
    sign_in users(:diretor)
    caneca = produtos(:caneca_antiga) # já indisponível, sem reservas

    assert_no_difference "Noticed::Event.count" do
      # a mesma transição não acontece (OLD.status já é indisponivel / status não muda)
      patch produto_path(caneca), params: { produto: { status: "indisponivel", nome: "Caneca x" } }
    end
  end

  private

  def notificado?(user, tipo)
    user.notifications.joins(:event).where(noticed_events: { type: tipo }).exists?
  end
end
