require "test_helper"

class AcoesControllerTest < ActionDispatch::IntegrationTest
  PUBLICADAS = %i[acao_site acao_hackathon acao_artigo].freeze

  test "index público lista só publicadas, com filtro por tipo" do
    get acoes_path
    ids = response.parsed_body["acoes"].map { |a| a["id"] }
    assert_equal PUBLICADAS.map { |f| acoes(f).id }.sort, ids.sort

    get acoes_path(tipo: "Projeto")
    assert_equal [ acoes(:acao_site).id ], response.parsed_body["acoes"].map { |a| a["id"] }
  end

  test "filtro de status é ignorado para anônimos" do
    get acoes_path(status: "rascunho")
    ids = response.parsed_body["acoes"].map { |a| a["id"] }
    assert_equal PUBLICADAS.map { |f| acoes(f).id }.sort, ids.sort
  end

  test "membro vê rascunhos com filtro de status" do
    sign_in users(:membro_user)
    get acoes_path(status: "rascunho")
    ids = response.parsed_body["acoes"].map { |a| a["id"] }
    assert_equal [ acoes(:acao_bot).id ], ids
  end

  test "show de publicada traz stack e contribuições" do
    get acao_path(acoes(:acao_site))

    body = response.parsed_body
    assert_equal "Projeto", body["tipo"]
    assert_equal "finalizado", body["detalhe"]["situacao"]
    assert_equal %w[Rails Ruby], body["detalhe"]["stack"].map { |t| t["nome"] }.sort
    papeis = body["detalhe"]["contribuicoes"].map { |c| c["papel"] }.sort
    assert_equal %w[backend frontend], papeis
  end

  test "show de rascunho é 403 para anônimo e ok para membro" do
    get acao_path(acoes(:acao_bot))
    assert_response :forbidden

    sign_in users(:membro_user)
    get acao_path(acoes(:acao_bot))
    assert_response :success
  end

  test "membro cria ação-projeto completa (aninhado)" do
    sign_in users(:membro_user)

    assert_difference [ "Acao.count", "Projeto.count" ], 1 do
      post acoes_path, params: {
        acao: {
          titulo: "API da Loja",
          descricao: "Backend da loja.",
          status: "publicada",
          projeto: { repo_url: "https://github.com/leds/loja", situacao: "em_desenvolvimento" },
          tecnologia_ids: [ tecnologias(:ruby).id ],
          contribuicoes: [ { member_id: members(:membro_comum).id, papel: "backend" } ]
        }
      }
    end

    assert_response :created
    body = response.parsed_body
    assert_equal [ "Ruby" ], body["detalhe"]["stack"].map { |t| t["nome"] }
    acao = Acao.find(body["id"])
    assert_equal members(:membro_comum), acao.criador
  end

  test "comunidade não cria ação" do
    sign_in users(:ana)
    post acoes_path, params: { acao: { titulo: "X" } }
    assert_response :forbidden
  end

  test "payload inválido retorna 422 com mensagens" do
    sign_in users(:membro_user)

    post acoes_path, params: {
      acao: { titulo: "Quebrada", projeto: { situacao: "finalizado" } }
    }
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].any?

    post acoes_path, params: {
      acao: { titulo: "Papel errado",
              contribuicoes: [ { member_id: members(:membro_comum).id, papel: "chefe" } ] }
    }
    assert_response :unprocessable_entity
  end

  test "update substitui stack e contribuições por inteiro" do
    sign_in users(:membro_user)

    patch acao_path(acoes(:acao_site)), params: {
      acao: {
        tecnologia_ids: [ tecnologias(:rails).id ],
        contribuicoes: [ { member_id: members(:membro_comum).id, papel: "infra" } ]
      }
    }

    assert_response :success
    projeto = projetos(:site_liga).reload
    assert_equal [ tecnologias(:rails) ], projeto.tecnologias
    assert_equal [ "infra" ], projeto.contribuicoes.pluck(:papel)
  end

  test "criar já arquivada exige diretoria+ (mesma regra do update)" do
    sign_in users(:membro_user)
    post acoes_path, params: {
      acao: { titulo: "Nasce morta", status: "arquivada", projeto: { situacao: "em_desenvolvimento" } }
    }
    assert_response :forbidden
  end

  test "usuário com role de membro mas sem perfil Member recebe 422 claro" do
    sign_in users(:membro_sem_perfil)
    post acoes_path, params: { acao: { titulo: "X", projeto: { situacao: "em_desenvolvimento" } } }

    assert_response :unprocessable_entity
    assert_match(/perfil de membro/, response.parsed_body["errors"].first)
  end

  test "create sem dados do projeto é 422, não Projeto vazio implícito" do
    sign_in users(:membro_user)
    assert_no_difference "Projeto.count" do
      post acoes_path, params: { acao: { titulo: "Sem detalhe" } }
    end
    assert_response :unprocessable_entity
  end

  test "payloads deformados não derrubam o endpoint (422/sucesso, nunca 500)" do
    sign_in users(:membro_user)

    post acoes_path, params: { acao: { titulo: "X", projeto: "oops" } }
    assert_response :unprocessable_entity

    patch acao_path(acoes(:acao_site)), params: { acao: { contribuicoes: [ "oops" ] } }
    assert response.status < 500, "esperava não-500, veio #{response.status}"

    patch acao_path(acoes(:acao_site)), params: { acao: { tecnologia_ids: [ 999_999 ] } }
    assert_response :unprocessable_entity
    assert_match(/tecnologia/i, response.parsed_body["errors"].first)
  end

  test "mudança só de stack/contribuições também gera trilha de auditoria" do
    sign_in users(:membro_user)

    assert_difference "PaperTrail::Version.count", 3 do # 2 destroys + 1 create
      patch acao_path(acoes(:acao_site)), params: {
        acao: { contribuicoes: [ { member_id: members(:membro_comum).id, papel: "infra" } ] }
      }
    end

    destroys = PaperTrail::Version.where(item_type: "Contribuicao", event: "destroy")
    assert_equal users(:membro_user).id.to_s, destroys.last.whodunnit
  end

  test "arquivar exige diretoria+" do
    sign_in users(:membro_user)
    patch acao_path(acoes(:acao_site)), params: { acao: { status: "arquivada" } }
    assert_response :forbidden

    sign_in users(:diretor)
    patch acao_path(acoes(:acao_site)), params: { acao: { status: "arquivada" } }
    assert_response :success
    assert acoes(:acao_site).reload.arquivada?
  end

  test "desarquivar também exige diretoria+" do
    acoes(:acao_site).update!(status: "arquivada")

    sign_in users(:membro_user)
    patch acao_path(acoes(:acao_site)), params: { acao: { status: "publicada" } }
    assert_response :forbidden
  end

  test "destaque traz publicadas para a landing" do
    get destaque_acoes_path
    ids = response.parsed_body["acoes"].map { |a| a["id"] }
    assert_equal PUBLICADAS.map { |f| acoes(f).id }.sort, ids.sort
  end

  test "update auditado registra o autor (whodunnit)" do
    sign_in users(:diretor)
    patch acao_path(acoes(:acao_site)), params: { acao: { titulo: "Renomeada" } }

    versao = acoes(:acao_site).versions.last
    assert_equal users(:diretor).id.to_s, versao.whodunnit
  end
end
