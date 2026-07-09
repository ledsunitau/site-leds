require "test_helper"

class IdeiasControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "propor ideia exige login" do
    post ideias_path, params: { ideia: { tipo: "projeto", titulo: "X" } }
    assert_response :redirect
  end

  test "qualquer usuário logado propõe (RN-01) e a gestão é notificada" do
    sign_in users(:ana) # role comunidade

    assert_difference "Ideia.count", 1 do
      post ideias_path, params: { ideia: { tipo: "projeto", titulo: "App da liga", descricao: "..." } }
    end
    assert_response :created

    ideia = Ideia.last
    assert ideia.pendente?
    assert_equal users(:ana), ideia.autor
    assert users(:diretor).notifications.joins(:event)
                          .where(noticed_events: { type: "IdeiaPropostaNotifier" }).exists?
  end

  test "tipo inválido é 422" do
    sign_in users(:ana)
    post ideias_path, params: { ideia: { tipo: "parceiro", titulo: "X" } }
    assert_response :unprocessable_entity
  end

  test "index lista só as ideias do próprio usuário" do
    minha = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Minha")
    Ideia.create!(autor: users(:membro_user), tipo: "projeto", titulo: "Alheia")

    sign_in users(:ana)
    get ideias_path
    ids = response.parsed_body["ideias"].map { |i| i["id"] }
    assert_equal [ minha.id ], ids
  end

  test "show: dono e gestão veem; terceiro é 403" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Minha")

    sign_in users(:ana) # dono
    get ideia_path(ideia)
    assert_response :success

    sign_in users(:membro_user) # nem dono nem gestão
    get ideia_path(ideia)
    assert_response :forbidden

    sign_in users(:diretor) # gestão
    get ideia_path(ideia)
    assert_response :success
  end

  test "gestor que propõe a própria ideia não notifica a si mesmo" do
    sign_in users(:diretor) # gestão
    post ideias_path, params: { ideia: { tipo: "projeto", titulo: "Ideia do diretor" } }
    assert_response :created

    assert_not users(:diretor).notifications.joins(:event)
                              .where(noticed_events: { type: "IdeiaPropostaNotifier" }).exists?,
               "o próprio proponente é excluído dos destinatários"
  end

  test "aprovar/rejeitar: gestão revisa e o autor é notificado; sem gestão é 403" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Revisar")

    sign_in users(:membro_user)
    post aprovar_ideia_path(ideia)
    assert_response :forbidden

    sign_in users(:diretor)
    post aprovar_ideia_path(ideia)
    assert_response :success
    assert ideia.reload.aprovada?
    assert_equal members(:diretor_cientifica), ideia.revisor
    assert users(:ana).notifications.joins(:event)
                      .where(noticed_events: { type: "IdeiaRevisadaNotifier" }).exists?
  end

  test "rejeitar: gestão rejeita e o autor é notificado" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Rejeitar")

    sign_in users(:diretor)
    post rejeitar_ideia_path(ideia)
    assert_response :success
    assert ideia.reload.rejeitada?
    assert users(:ana).notifications.joins(:event)
                      .where(noticed_events: { type: "IdeiaRevisadaNotifier" }).exists?
  end

  test "aprovar ideia já revisada é 422 (transição inválida)" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "X", status: "rejeitada")

    sign_in users(:diretor)
    post aprovar_ideia_path(ideia)
    assert_response :unprocessable_entity
  end

  test "ação vincula ideia aprovada (idealizador) via acao[ideia_id]" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Vira ação", status: "aprovada")

    sign_in users(:membro_user)
    post acoes_path, params: {
      acao: {
        titulo: "Projeto da ideia",
        ideia_id: ideia.id,
        projeto: { situacao: "em_desenvolvimento" }
      }
    }
    assert_response :created
    assert_equal ideia.id, Acao.find(response.parsed_body["id"]).ideia_id
  end

  test "fila de aprovação do admin inclui ideias pendentes" do
    pendente = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Pendente")
    Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Já aprovada", status: "aprovada")

    sign_in users(:diretor)
    get admin_approvals_path
    ids = response.parsed_body["ideias"].map { |i| i["id"] }
    assert_equal [ pendente.id ], ids

    # paginar a fila de posts (pagina_posts) NÃO pode esconder as ideias
    get admin_approvals_path(pagina_posts: 2)
    assert_equal [ pendente.id ], response.parsed_body["ideias"].map { |i| i["id"] }
  end
end
