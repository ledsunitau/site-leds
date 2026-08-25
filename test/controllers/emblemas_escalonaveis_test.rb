require "test_helper"

# Fluxos ponta a ponta da parte 2: resgate com vagas, hover com os registros,
# ranking de elo e emblema concedido na confirmação do pagamento.
class EmblemasEscalonaveisTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.delete("emblemas/total_usuarios") }

  # ---------------------------------------------------- Link com descrição

  test "o link da maratona registra com a descrição dele e sobe o rank" do
    sign_in users(:diretor)

    get emblema_convite_path(emblema_convites(:maratona_link).token)
    assert_redirected_to emblemas_path

    vinculo = emblemas(:maratonista).emblema_usuarios.find_by(user: users(:diretor))
    assert_equal "Maratona SBC 2026", vinculo.conquistas.first.descricao
    assert_equal "Bronze", vinculo.nivel.nome
    assert_match(/Bronze/, flash[:notice])
  end

  test "resgatar o mesmo link de novo acrescenta registro no escalonável" do
    sign_in users(:diretor)
    2.times { get emblema_convite_path(emblema_convites(:maratona_link).token) }

    vinculo = emblemas(:maratonista).emblema_usuarios.find_by(user: users(:diretor))
    assert_equal 2, vinculo.conquistas_count
    assert_equal "Prata", vinculo.nivel.nome
  end

  # ------------------------------------------------------------- Vagas

  test "o link de 2 vagas para de aceitar no terceiro" do
    convite = emblema_convites(:beta_com_vagas)

    [ users(:diretor), users(:membro_user) ].each do |usuario|
      sign_in usuario
      get emblema_convite_path(convite.token)
      assert_includes usuario.emblemas.reload, emblemas(:convidado_beta)
    end

    sign_in users(:escritor_user)
    get emblema_convite_path(convite.token)

    assert_match(/vagas acabaram/i, flash[:alert])
    assert_not_includes users(:escritor_user).emblemas.reload, emblemas(:convidado_beta)
    assert_equal 2, convite.reload.usos
  end

  test "resgate repetido de emblema único devolve a vaga" do
    convite = emblema_convites(:beta_com_vagas)
    sign_in users(:diretor)

    get emblema_convite_path(convite.token)
    assert_equal 1, convite.reload.usos

    get emblema_convite_path(convite.token)
    assert_equal 1, convite.reload.usos, "clique repetido não pode queimar a vaga de outro"
    assert_match(/já tem/i, flash[:notice])
  end

  # ------------------------------------------------------------- Hover

  test "o perfil público lista os registros do emblema com descrição e data" do
    sign_in users(:diretor)
    get usuario_path(users(:ana))

    assert_response :success
    assert_select ".emblema-registros" do
      assert_select ".emblema-registro-nome", text: "Maratona SBC 2025"
      assert_select ".emblema-registro-nome", text: "Maratona Interna 2026"
    end
  end

  # ------------------------------------------------------------ Ranking

  test "o ranking mostra a escada e o topo só do elo final" do
    users(:ana).recalcular_elo!
    users(:diretor).update_columns(pontos_emblemas: 99, elo_id: elos(:lenda).id)

    sign_in users(:ana)
    get ranking_emblemas_path

    assert_response :success
    assert_select ".ranking-degrau", Elo.count
    # ana está na Prata; o topo lista só quem está na Lenda
    assert_select ".ranking-degrau.atual .ranking-degrau-nome", text: "Prata"
    nomes = css_select(".ranking-nome").map { |n| n.text.squish }
    assert_includes nomes, "Dario Diretor"
    assert_not_includes nomes, "Ana Comunidade"
  end

  test "o ranking exige login" do
    get ranking_emblemas_path
    assert_redirected_to new_user_session_path
  end

  # ------------------------------------------------------------- Compra

  test "pagamento confirmado concede o emblema do produto" do
    pedido = pedido_de(users(:diretor), produtos(:camiseta))

    assert_difference -> { EmblemaUsuario.count }, 1 do
      pedido.marcar_pago!
    end
    assert_includes users(:diretor).emblemas.reload, emblemas(:comprador_pioneiro)
  end

  test "webhook repetido não concede duas vezes" do
    pedido = pedido_de(users(:diretor), produtos(:camiseta))
    pedido.marcar_pago!

    assert_no_difference -> { EmblemaUsuario.count } do
      3.times { pedido.marcar_pago! } # marcar_pago! é idempotente
    end
  end

  test "passado o teto de 2 donos, o terceiro comprador não ganha" do
    [ users(:diretor), users(:membro_user), users(:escritor_user) ].each do |comprador|
      pedido_de(comprador, produtos(:camiseta)).marcar_pago!
    end

    assert_equal 2, emblemas(:comprador_pioneiro).reload.usuarios_count
    assert_not_includes users(:escritor_user).emblemas.reload, emblemas(:comprador_pioneiro)
  end

  test "comprar produto sem emblema vinculado não concede nada" do
    pedido = pedido_de(users(:diretor), produtos(:moletom))

    assert_no_difference -> { EmblemaUsuario.count } do
      pedido.marcar_pago!
    end
  end

  private

  def pedido_de(comprador, produto)
    pedido = Pedido.create!(comprador: comprador, total: produto.preco,
                            tipo_entrega: "retirada", status: "aguardando_pagamento")
    pedido.itens.create!(produto: produto, variante: produto.variantes.first,
                         quantidade: 1, preco_unitario: produto.preco)
    pedido
  end
end
