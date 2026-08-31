require "test_helper"

# Cadastro de funções (papéis das ações). O que importa aqui não é o CRUD, é o
# que ele RECUSA: as junções guardam o papel em varchar, então apagar ou
# renomear uma função em uso deixaria linhas apontando para um papel que não
# existe mais — e elas parariam de validar na próxima edição da ação.
class PainelFuncoesTest < ActionDispatch::IntegrationTest
  test "a tela exige gestão" do
    sign_in users(:membro_user)
    get painel_funcoes_path
    assert_redirected_to root_path
  end

  test "a tela lista as funções das duas modalidades com o uso de cada uma" do
    sign_in users(:diretor)
    get painel_funcoes_path
    assert_response :success

    assert_select "section.painel-panel", count: 2
    assert_select "li.painel-linha", count: Funcao.count

    # backend está numa contribuição da fixture, mas segue renomeável
    linha = css_select("li.painel-linha").find { |li| li.css("input[value=backend]").any? }
    assert linha, "a função backend precisa aparecer na lista"
    assert_empty linha.css("input[readonly]"), "função em uso ainda pode ser renomeada"
    assert linha.css("input[type=submit]").any?

    # protegida trava o nome e não tem botão de apagar
    protegida = css_select("li.painel-linha").find { |li| li.css("input[value=organizador]").any? }
    assert protegida.css("input[readonly]").any?, "função do sistema não pode ser renomeada"
    assert_empty protegida.css("button"), "função protegida não pode ter botão de apagar"
  end

  test "função criada aparece nos papéis do formulário de ação" do
    sign_in users(:diretor)

    assert_difference -> { Funcao.count }, 1 do
      post painel_funcoes_path, params: { item: { modalidade: "projeto", nome: "devops" } }
    end

    get edit_painel_acao_path(acoes(:acao_site))
    assert_select "input[name*='[papeis][]'][value=?]", "devops"
  end

  test "modalidade fora do conjunto fechado não cria" do
    sign_in users(:diretor)

    assert_no_difference -> { Funcao.count } do
      post painel_funcoes_path, params: { item: { modalidade: "artigo", nome: "revisor" } }
    end
  end

  test "função protegida não é apagada" do
    sign_in users(:diretor)
    organizador = funcoes(:organizador)

    assert_no_difference -> { Funcao.count } do
      delete painel_funcao_path(organizador)
    end
    assert_redirected_to painel_funcoes_path
    assert_match "não pode ser apagada", flash[:alert]
  end

  test "função em uso não é apagada" do
    sign_in users(:diretor)

    assert_no_difference -> { Funcao.count } do
      delete painel_funcao_path(funcoes(:backend)) # contribuicoes(:diretor_backend) usa
    end
    assert_match "está em uso", flash[:alert]
  end

  test "função protegida não é renomeada" do
    sign_in users(:diretor)

    patch painel_funcao_path(funcoes(:organizador)), params: { item: { nome: "anfitriao" } }
    assert_match "não pode ser renomeada", flash[:alert]
    assert_equal "organizador", funcoes(:organizador).reload.nome
  end

  # O ponto da feature: o nome é a chave nas junções, então renomear tem que
  # arrastar as atribuições — senão elas viram papel inexistente e a ação para
  # de salvar.
  test "renomear uma função em uso reescreve as atribuições junto" do
    sign_in users(:diretor)
    contribuicao = contribuicoes(:diretor_backend)

    patch painel_funcao_path(funcoes(:backend)), params: { item: { nome: "back-end" } }
    assert_redirected_to painel_funcoes_path

    assert_equal "back-end", funcoes(:backend).reload.nome
    assert_equal "back-end", contribuicao.reload.papel
    assert_empty Contribuicao.where(papel: "backend"), "não pode sobrar linha com o nome antigo"
    # e a ação continua salvável — era isso que quebrava sem o arrasto
    assert contribuicao.valid?
  end

  test "renomear participação de evento também arrasta as linhas" do
    sign_in users(:diretor)
    livre = Funcao.create!(modalidade: "evento", nome: "monitoria")
    participacao = eventos(:hackathon).evento_membros.create!(member: members(:vice), papel: "monitoria")

    patch painel_funcao_path(livre), params: { item: { nome: "mentoria" } }
    assert_equal "mentoria", participacao.reload.papel
  end

  test "o arrasto do rename gera versão de auditoria por linha" do
    sign_in users(:diretor)

    assert_difference -> { PaperTrail::Version.where(item_type: "Contribuicao").count }, 1 do
      patch painel_funcao_path(funcoes(:backend)), params: { item: { nome: "back-end" } }
    end
  end

  test "função sem uso é renomeada e apagada" do
    sign_in users(:diretor)
    livre = Funcao.create!(modalidade: "projeto", nome: "monitoria")

    patch painel_funcao_path(livre), params: { item: { nome: "mentoria" } }
    assert_equal "mentoria", livre.reload.nome

    assert_difference -> { Funcao.count }, -1 do
      delete painel_funcao_path(livre)
    end
  end

  test "renomear para um nome já existente não mexe nas atribuições" do
    sign_in users(:diretor)
    contribuicao = contribuicoes(:diretor_backend)

    patch painel_funcao_path(funcoes(:backend)), params: { item: { nome: "infra" } }

    assert_equal "backend", funcoes(:backend).reload.nome
    assert_equal "backend", contribuicao.reload.papel, "a transação tinha que voltar inteira"
  end
end
