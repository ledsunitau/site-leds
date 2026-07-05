require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "index público lista só publicados, mais recente primeiro, com filtro por tipo" do
    get posts_path
    ids = response.parsed_body["posts"].map { |p| p["id"] }
    assert_equal [ posts(:blog_publicado), posts(:noticia_publicada), posts(:noticia_antiga) ].map(&:id), ids

    get posts_path(tipo: "blog")
    assert_equal [ posts(:blog_publicado).id ], response.parsed_body["posts"].map { |p| p["id"] }
  end

  test "filtro de status é ignorado para quem não aprova; gestão vê a fila de aprovação" do
    get posts_path(status: "em_aprovacao")
    assert_equal 3, response.parsed_body["posts"].size, "anônimo segue vendo só publicados"

    sign_in users(:diretor)
    get posts_path(status: "em_aprovacao")
    assert_equal [ posts(:blog_em_aprovacao).id ], response.parsed_body["posts"].map { |p| p["id"] }
  end

  test "index é paginado (página fora do alcance vem vazia)" do
    get posts_path(pagina: "2")
    assert_equal [], response.parsed_body["posts"]

    get posts_path(pagina: "-3")
    assert_equal 3, response.parsed_body["posts"].size, "página inválida cai na primeira"
  end

  test "show de publicado é público e traz o corpo rico" do
    get post_path(posts(:noticia_publicada))

    body = response.parsed_body
    assert_equal "publicado", body["status"]
    assert_match "grafos", body["corpo"]
    assert_equal "Marcos Membro", body["autor"]["name"]
  end

  test "show de rascunho: 403 para anônimo e não-dono; ok para dono e gestão" do
    get post_path(posts(:rascunho_do_membro))
    assert_response :forbidden

    sign_in users(:escritor_user)
    get post_path(posts(:rascunho_do_membro))
    assert_response :forbidden

    sign_in users(:membro_user)
    get post_path(posts(:rascunho_do_membro))
    assert_response :success

    sign_in users(:diretor)
    get post_path(posts(:rascunho_do_membro))
    assert_response :success
  end

  test "comunidade não escreve; membro cria notícia que nasce rascunho" do
    sign_in users(:ana)
    post posts_path, params: { post: { tipo: "noticia", titulo: "X" } }
    assert_response :forbidden

    sign_in users(:membro_user)
    assert_difference "Post.count", 1 do
      post posts_path, params: {
        post: { tipo: "noticia", titulo: "Semana de provas", corpo: "<p>Vem aí.</p>" }
      }
    end
    assert_response :created
    assert_equal "rascunho", response.parsed_body["status"]
  end

  test "escritor cria blog mas não notícia; membro também escreve blog" do
    sign_in users(:escritor_user)
    post posts_path, params: { post: { tipo: "blog", titulo: "Dicas de estudo" } }
    assert_response :created

    post posts_path, params: { post: { tipo: "noticia", titulo: "Furando a regra" } }
    assert_response :forbidden

    sign_in users(:membro_user)
    post posts_path, params: { post: { tipo: "blog", titulo: "Blog de membro" } }
    assert_response :created
  end

  test "status do payload é ignorado: ninguém nasce publicado (RN-02)" do
    sign_in users(:membro_user)
    post posts_path, params: {
      post: { tipo: "noticia", titulo: "Auto-publicada?", status: "publicado" }
    }

    assert_response :created
    assert_equal "rascunho", response.parsed_body["status"]
  end

  test "tipo inválido/ausente é 422 para qualquer autor — não um 403 enganoso" do
    sign_in users(:membro_user)
    post posts_path, params: { post: { tipo: "propaganda", titulo: "X" } }
    assert_response :unprocessable_entity

    # escritor não escreve notícia, mas payload sem tipo é problema de
    # validação, não de permissão
    sign_in users(:escritor_user)
    post posts_path, params: { post: { titulo: "Sem tipo" } }
    assert_response :unprocessable_entity
  end

  test "fluxo completo: submeter → aprovar publica, registra aprovador e anuncia no Discord" do
    sign_in users(:membro_user)
    post submeter_post_path(posts(:rascunho_do_membro))
    assert_response :success
    assert posts(:rascunho_do_membro).reload.em_aprovacao?

    sign_in users(:diretor)
    assert_enqueued_with job: DiscordWebhookJob, args: [ posts(:rascunho_do_membro).id ] do
      post aprovar_post_path(posts(:rascunho_do_membro))
    end

    aprovado = posts(:rascunho_do_membro).reload
    assert aprovado.publicado?
    assert_equal members(:diretor_cientifica), aprovado.aprovador
    assert aprovado.approved_at.present?
    assert aprovado.published_at.present?
  end

  test "submeter post alheio é 403; aprovar/rejeitar sem ser gestão é 403" do
    sign_in users(:escritor_user)
    post submeter_post_path(posts(:rascunho_do_membro))
    assert_response :forbidden

    sign_in users(:membro_user)
    post aprovar_post_path(posts(:blog_em_aprovacao))
    assert_response :forbidden
    post rejeitar_post_path(posts(:blog_em_aprovacao))
    assert_response :forbidden
  end

  test "aprovar rascunho (sem submissão) é 422 — transição inválida" do
    sign_in users(:diretor)
    post aprovar_post_path(posts(:rascunho_do_membro))

    assert_response :unprocessable_entity
    assert posts(:rascunho_do_membro).reload.rascunho?
  end

  test "rejeitado pode ser editado e resubmetido pelo autor" do
    sign_in users(:diretor)
    post rejeitar_post_path(posts(:blog_em_aprovacao))
    assert posts(:blog_em_aprovacao).reload.rejeitado?

    sign_in users(:escritor_user)
    patch post_path(posts(:blog_em_aprovacao)), params: { post: { titulo: "Corrigido" } }
    assert_response :success

    post submeter_post_path(posts(:blog_em_aprovacao))
    assert posts(:blog_em_aprovacao).reload.em_aprovacao?
  end

  test "editar publicado volta para em_aprovacao e derruba a aprovação (RF-NOV-06)" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)), params: { post: { titulo: "Título corrigido" } }

    assert_response :success
    editado = posts(:noticia_publicada).reload
    assert editado.em_aprovacao?
    assert_nil editado.aprovador
    assert_nil editado.approved_at
    assert editado.published_at.present?, "primeira publicação é preservada"

    get posts_path
    assert_not_includes response.parsed_body["posts"].map { |p| p["id"] }, editado.id
  end

  test "editar SÓ o corpo de publicado também volta para em_aprovacao (RN-02)" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)), params: { post: { corpo: "<p>Outro texto.</p>" } }

    assert_response :success
    assert posts(:noticia_publicada).reload.em_aprovacao?
  end

  test "PATCH sem mudança nenhuma não derruba a publicação" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)),
          params: { post: { titulo: posts(:noticia_publicada).titulo } }

    assert_response :success
    assert posts(:noticia_publicada).reload.publicado?
  end

  test "re-aprovar edição anuncia de novo no Discord (status virou publicado — RF-NOV-11)" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)), params: { post: { titulo: "Editada" } }
    published_at_original = posts(:noticia_publicada).reload.published_at

    sign_in users(:diretor)
    assert_enqueued_with job: DiscordWebhookJob do
      post aprovar_post_path(posts(:noticia_publicada))
    end
    reaprovado = posts(:noticia_publicada).reload
    assert reaprovado.publicado?
    assert_equal published_at_original, reaprovado.published_at, "não fura a fila das últimas"
  end

  test "aprovar um post já publicado é 422 (guard revalida sob lock)" do
    sign_in users(:diretor)
    post aprovar_post_path(posts(:noticia_publicada))

    assert_response :unprocessable_entity
  end

  test "escritor não transforma o próprio blog em notícia" do
    sign_in users(:escritor_user)
    patch post_path(posts(:blog_em_aprovacao)), params: { post: { tipo: "noticia" } }

    assert_response :forbidden
    assert posts(:blog_em_aprovacao).reload.blog?
  end

  test "dono apaga rascunho, mas não publicado; gestão apaga qualquer um" do
    sign_in users(:membro_user)
    assert_difference "Post.count", -1 do
      delete post_path(posts(:rascunho_do_membro))
    end
    assert_response :no_content

    delete post_path(posts(:noticia_publicada))
    assert_response :forbidden

    sign_in users(:diretor)
    assert_difference "Post.count", -1 do
      delete post_path(posts(:noticia_publicada))
    end
  end

  test "ultimas traz só notícias publicadas para a landing (RF-INI-07)" do
    get ultimas_posts_path

    ids = response.parsed_body["posts"].map { |p| p["id"] }
    assert_equal [ posts(:noticia_publicada).id, posts(:noticia_antiga).id ], ids
  end

  test "meus lista os posts do autor em qualquer status" do
    sign_in users(:membro_user)
    get meus_posts_path

    ids = response.parsed_body["posts"].map { |p| p["id"] }
    assert_equal [ posts(:noticia_publicada).id, posts(:rascunho_do_membro).id ].sort, ids.sort
  end

  test "versoes registra mudanças de título E de corpo, com autor (RF-NOV-07)" do
    sign_in users(:membro_user)
    patch post_path(posts(:rascunho_do_membro)), params: {
      post: { titulo: "Novo título", corpo: "<p>Corpo novo</p>" }
    }

    get versoes_post_path(posts(:rascunho_do_membro))
    versoes = response.parsed_body["versoes"]

    itens = versoes.map { |v| v["item"] }
    assert_includes itens, "post", "mudança de coluna do post"
    assert_includes itens, "corpo", "mudança no rich text"
    assert(versoes.all? { |v| v["whodunnit"] == users(:membro_user).id.to_s })

    sign_in users(:escritor_user)
    get versoes_post_path(posts(:rascunho_do_membro))
    assert_response :forbidden
  end
end
