require "test_helper"

# RF-NOV-08/09/10 + RF-ADM-05: comentar, denunciar, moderar e a aba de denúncias.
class ComentariosTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # --- comentar (RF-NOV-08) ---

  test "leitura pública mostra só os visíveis do post pedido; a gestão vê os moderados" do
    get post_comentarios_path(posts(:noticia_publicada))
    assert_response :success
    ids = response.parsed_body["comentarios"].map { |c| c["id"] }
    assert_equal [ comentarios(:visivel_na_noticia).id ], ids,
                 "oculto some do público e o comentário do outro post não vaza"

    sign_in users(:diretor)
    get post_comentarios_path(posts(:noticia_publicada))
    ids = response.parsed_body["comentarios"].map { |c| c["id"] }
    assert_equal [ comentarios(:visivel_na_noticia).id, comentarios(:oculto_na_noticia).id ].sort,
                 ids.sort, "gestão vê os moderados, ainda escopado no post"
  end

  test "comentários de post fora do ar não são públicos (o post é 403, a discussão também)" do
    get post_comentarios_path(posts(:rascunho_do_membro))
    assert_response :forbidden

    sign_in users(:diretor)
    get post_comentarios_path(posts(:rascunho_do_membro))
    assert_response :success, "gestão enxerga"
  end

  test "comentar exige login e nasce visível (sem fila)" do
    post post_comentarios_path(posts(:noticia_publicada)), params: { comentario: { corpo: "Massa!" } }
    assert_response :redirect

    sign_in users(:ana)
    assert_difference "Comentario.count", 1 do
      post post_comentarios_path(posts(:noticia_publicada)), params: { comentario: { corpo: "Massa!" } }
    end
    assert_response :created
    assert_equal "visivel", response.parsed_body["status"]
    assert_equal users(:ana), Comentario.last.autor
  end

  test "não se comenta em post que não está no ar" do
    sign_in users(:ana)
    assert_no_difference "Comentario.count" do
      post post_comentarios_path(posts(:rascunho_do_membro)), params: { comentario: { corpo: "oi" } }
    end
    assert_response :unprocessable_entity
  end

  test "corpo vazio é 422" do
    sign_in users(:ana)
    post post_comentarios_path(posts(:noticia_publicada)), params: { comentario: { corpo: "" } }
    assert_response :unprocessable_entity
  end

  # --- moderar (RF-NOV-10) ---

  test "moderar é da gestão; oculta sem apagar e registra quem moderou" do
    comentario = comentarios(:visivel_na_noticia)

    sign_in users(:membro_user)
    post moderar_comentario_path(comentario), params: { status: "oculto" }
    assert_response :forbidden

    sign_in users(:diretor)
    assert_no_difference "Comentario.count" do
      post moderar_comentario_path(comentario), params: { status: "oculto" }
    end
    assert_response :success

    comentario.reload
    assert comentario.oculto?
    assert_equal members(:diretor_cientifica), comentario.moderador
    assert comentario.moderated_at.present?
  end

  test "moderar para status fora de oculto/removido é 422" do
    sign_in users(:diretor)
    post moderar_comentario_path(comentarios(:visivel_na_noticia)), params: { status: "visivel" }
    assert_response :unprocessable_entity
  end

  # --- denunciar (RF-NOV-09) ---

  test "denunciar exige login, cai pendente e avisa a gestão" do
    comentario = comentarios(:visivel_na_noticia)

    post comentario_denuncias_path(comentario), params: { denuncia: { motivo: "spam" } }
    assert_response :redirect

    sign_in users(:membro_user)
    assert_difference "Denuncia.count", 1 do
      post comentario_denuncias_path(comentario), params: { denuncia: { motivo: "spam" } }
    end
    assert_response :created

    denuncia = Denuncia.last
    assert denuncia.pendente?
    assert_equal users(:membro_user), denuncia.denunciante
    assert users(:diretor).notifications.joins(:event)
                          .where(noticed_events: { type: "DenunciaNotifier" }).exists?
  end

  test "o mesmo usuário não empilha denúncias no mesmo comentário" do
    comentario = comentarios(:visivel_na_noticia)
    sign_in users(:membro_user)

    post comentario_denuncias_path(comentario), params: { denuncia: { motivo: "spam" } }
    assert_response :created

    assert_no_difference "Denuncia.count" do
      post comentario_denuncias_path(comentario), params: { denuncia: { motivo: "de novo" } }
    end
    assert_response :unprocessable_entity
    assert_equal [ "Você já denunciou este comentário." ], response.parsed_body["errors"],
                 "erro em prosa pt-BR, não 'User já está em uso'"
  end

  test "comentário já moderado não é denunciável (pendência nasceria sem trabalho)" do
    sign_in users(:membro_user)
    assert_no_difference "Denuncia.count" do
      post comentario_denuncias_path(comentarios(:oculto_na_noticia)), params: { denuncia: { motivo: "x" } }
    end
    assert_response :unprocessable_entity
  end

  test "denúncias anonimizadas (autor apagou a conta) convivem no mesmo comentário" do
    comentario = comentarios(:visivel_na_noticia)
    comentario.denuncias.create!(denunciante: nil, motivo: "uma")

    assert_difference "Denuncia.count", 1 do
      comentario.denuncias.create!(denunciante: nil, motivo: "outra")
    end
  end

  # --- aba de denúncias (RF-ADM-05) ---

  test "aba de denúncias exige gestão e lista as pendentes com o comentário" do
    denuncia = comentarios(:visivel_na_noticia).denuncias
                                               .create!(denunciante: users(:membro_user), motivo: "spam")

    get admin_denuncias_path
    assert_response :redirect

    sign_in users(:membro_user)
    get admin_denuncias_path
    assert_response :forbidden

    sign_in users(:diretor)
    get admin_denuncias_path
    assert_response :success
    body = response.parsed_body["denuncias"]
    assert_equal [ denuncia.id ], body.map { |d| d["id"] },
                 "a fixture resolvida fica fora: a aba lista pendentes por padrão"
    assert_equal "Parabéns pela conquista!", body.first["comentario"]["corpo"],
                 "a gestão precisa ver o conteúdo denunciado para julgar"
    assert_equal users(:membro_user).id, body.first["denunciante"]["id"],
                 "e quem denunciou, para enxergar denúncia em série"

    # o filtro explícito alcança as resolvidas
    get admin_denuncias_path(status: "resolvida")
    assert_equal [ denuncias(:resolvida_antiga).id ], response.parsed_body["denuncias"].map { |d| d["id"] }
  end

  test "resolver a denúncia registra quem resolveu; resolver de novo é 422" do
    denuncia = comentarios(:visivel_na_noticia).denuncias
                                               .create!(denunciante: users(:membro_user), motivo: "spam")

    sign_in users(:diretor)
    post resolver_admin_denuncia_path(denuncia)
    assert_response :success

    denuncia.reload
    assert denuncia.resolvida?
    assert_equal members(:diretor_cientifica), denuncia.resolvedor
    assert denuncia.resolved_at.present?
    assert comentarios(:visivel_na_noticia).reload.visivel?,
           "resolver não modera: julgar improcedente é uma decisão possível"

    post resolver_admin_denuncia_path(denuncia)
    assert_response :unprocessable_entity
  end
end
