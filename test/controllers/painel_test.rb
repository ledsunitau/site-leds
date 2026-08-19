require "test_helper"

# Painel de gestão (HTML). O gate aqui REDIRECIONA — diferente do /admin, que
# devolve 403 porque é API JSON. Os dois convivem de propósito.
class PainelTest < ActionDispatch::IntegrationTest
  test "o painel exige gestão: deslogado e papel comum não entram" do
    get painel_path
    assert_redirected_to new_user_session_path

    sign_in users(:ana)
    get painel_path
    assert_redirected_to root_path
    assert_equal "Acesso restrito à gestão.", flash[:alert]

    sign_in users(:membro_user)
    get painel_path
    assert_redirected_to root_path
  end

  test "diretoria e presidência abrem o dashboard" do
    sign_in users(:diretor)
    get painel_path
    assert_response :success

    sign_in users(:presidente_user)
    get painel_path
    assert_response :success
  end

  test "o dashboard mostra KPIs, pendências e atividade" do
    # as fixtures entram sem PaperTrail; a timeline precisa de uma versão real
    Categoria.create!(nome: "Vestuário")

    sign_in users(:diretor)
    get painel_path

    # quatro cartões de destaque: comunidade, ações, novidades e receita
    assert_select ".painel-destaque", count: 4
    assert_select ".painel-nav-link"
    # a fila de aprovação das fixtures aparece como alerta, com o contexto
    assert_select ".painel-alertas .painel-alerta", minimum: 1
    assert_select ".painel-alerta-pe", minimum: 1, message: "cada alerta explica o que é"
    # os dois painéis de tráfego dividem a mesma faixa de altura
    assert_select ".painel-igual > .painel-panel", count: 2
    assert_select ".painel-timeline-cards"
  end

  test "o link do painel só aparece no drawer para a gestão" do
    sign_in users(:ana)
    get root_path
    assert_select "a.drawer-gestao", count: 0

    sign_in users(:diretor)
    get root_path
    assert_select "a.drawer-gestao", count: 1
  end

  test "o contrato JSON do /admin continua 403 para papel comum" do
    sign_in users(:membro_user)
    get admin_approvals_path
    assert_response :forbidden, "o gate do /admin não pode virar redirect"
  end
end
