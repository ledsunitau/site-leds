require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "index público lista só publicados, mais recente primeiro, com filtro por tipo" do
    get posts_path, as: :json
    ids = response.parsed_body["posts"].map { |p| p["id"] }
    assert_equal [ posts(:blog_publicado), posts(:noticia_publicada), posts(:noticia_antiga) ].map(&:id), ids

    get posts_path(tipo: "blog"), as: :json
    assert_equal [ posts(:blog_publicado).id ], response.parsed_body["posts"].map { |p| p["id"] }
  end

  test "filtro de status é ignorado para quem não aprova; gestão vê a fila de aprovação" do
    get posts_path(status: "em_aprovacao"), as: :json
    assert_equal 3, response.parsed_body["posts"].size, "anônimo segue vendo só publicados"

    sign_in users(:diretor)
    get posts_path(status: "em_aprovacao"), as: :json
    assert_equal [ posts(:blog_em_aprovacao).id ], response.parsed_body["posts"].map { |p| p["id"] }
  end

  test "index é paginado (página fora do alcance vem vazia)" do
    get posts_path(pagina: "2"), as: :json
    assert_equal [], response.parsed_body["posts"]

    get posts_path(pagina: "-3"), as: :json
    assert_equal 3, response.parsed_body["posts"].size, "página inválida cai na primeira"
  end

  test "show de publicado é público e traz o corpo rico" do
    get post_path(posts(:noticia_publicada)), as: :json

    body = response.parsed_body
    assert_equal "publicado", body["status"]
    assert_match "grafos", body["corpo"]
    assert_equal "Marcos Membro", body["autor"]["name"]
  end

  test "show de rascunho: 403 para anônimo e não-dono; ok para dono e gestão" do
    get post_path(posts(:rascunho_do_membro)), as: :json
    assert_response :forbidden

    sign_in users(:escritor_user)
    get post_path(posts(:rascunho_do_membro)), as: :json
    assert_response :forbidden

    sign_in users(:membro_user)
    get post_path(posts(:rascunho_do_membro)), as: :json
    assert_response :success

    sign_in users(:diretor)
    get post_path(posts(:rascunho_do_membro)), as: :json
    assert_response :success
  end

  test "comunidade não escreve; membro cria notícia que nasce rascunho" do
    sign_in users(:ana)
    post posts_path, params: { post: { tipo: "noticia", titulo: "X" } }, as: :json
    assert_response :forbidden

    sign_in users(:membro_user)
    assert_difference "Post.count", 1 do
      post posts_path, params: {
        post: { tipo: "noticia", titulo: "Semana de provas", corpo: "<p>Vem aí.</p>" }
      }, as: :json
    end
    assert_response :created
    assert_equal "rascunho", response.parsed_body["status"]
  end

  test "escritor cria blog mas não notícia; membro também escreve blog" do
    sign_in users(:escritor_user)
    post posts_path, params: { post: { tipo: "blog", titulo: "Dicas de estudo" } }, as: :json
    assert_response :created

    post posts_path, params: { post: { tipo: "noticia", titulo: "Furando a regra" } }, as: :json
    assert_response :forbidden

    sign_in users(:membro_user)
    post posts_path, params: { post: { tipo: "blog", titulo: "Blog de membro" } }, as: :json
    assert_response :created
  end

  test "status do payload é ignorado: ninguém nasce publicado (RN-02)" do
    sign_in users(:membro_user)
    post posts_path, params: {
      post: { tipo: "noticia", titulo: "Auto-publicada?", status: "publicado" }
    }, as: :json

    assert_response :created
    assert_equal "rascunho", response.parsed_body["status"]
  end

  test "tipo inválido/ausente é 422 para qualquer autor — não um 403 enganoso" do
    sign_in users(:membro_user)
    post posts_path, params: { post: { tipo: "propaganda", titulo: "X" } }, as: :json
    assert_response :unprocessable_entity

    # escritor não escreve notícia, mas payload sem tipo é problema de
    # validação, não de permissão
    sign_in users(:escritor_user)
    post posts_path, params: { post: { titulo: "Sem tipo" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "fluxo completo: submeter → aprovar publica, registra aprovador e anuncia no Discord" do
    sign_in users(:membro_user)
    post submeter_post_path(posts(:rascunho_do_membro)), as: :json
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
    patch post_path(posts(:blog_em_aprovacao)), params: { post: { titulo: "Corrigido" } }, as: :json
    assert_response :success

    post submeter_post_path(posts(:blog_em_aprovacao))
    assert posts(:blog_em_aprovacao).reload.em_aprovacao?
  end

  test "editar publicado volta para em_aprovacao e derruba a aprovação (RF-NOV-06)" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)), params: { post: { titulo: "Título corrigido" } }, as: :json

    assert_response :success
    editado = posts(:noticia_publicada).reload
    assert editado.em_aprovacao?
    assert_nil editado.aprovador
    assert_nil editado.approved_at
    assert editado.published_at.present?, "primeira publicação é preservada"

    get posts_path, as: :json
    assert_not_includes response.parsed_body["posts"].map { |p| p["id"] }, editado.id
  end

  test "editar SÓ o corpo de publicado também volta para em_aprovacao (RN-02)" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)), params: { post: { corpo: "<p>Outro texto.</p>" } }, as: :json

    assert_response :success
    assert posts(:noticia_publicada).reload.em_aprovacao?
  end

  test "PATCH sem mudança nenhuma não derruba a publicação" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)),
          params: { post: { titulo: posts(:noticia_publicada).titulo } }, as: :json

    assert_response :success
    assert posts(:noticia_publicada).reload.publicado?
  end

  test "re-aprovar edição anuncia de novo no Discord (status virou publicado — RF-NOV-11)" do
    sign_in users(:membro_user)
    patch post_path(posts(:noticia_publicada)), params: { post: { titulo: "Editada" } }, as: :json
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
    get meus_posts_path, as: :json

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

  # --- tela de escrita fora do painel (RF-NOV-04) ---
  #
  # Estes existem por causa do buraco que a feature fecha: a PostPolicy já
  # AUTORIZAVA o escritor a criar um blog, mas a única tela de escrita vivia em
  # /painel, atrás do exigir_gestao!. Autorização sem tela alcançável não vale
  # nada, e o teste que faltava era justamente o que amarra as duas coisas.

  test "escritor e jornalista abrem a tela de escrita; comunidade não" do
    sign_in users(:escritor_user)
    get new_post_path
    assert_response :success

    sign_in users(:jornalista_user)
    get new_post_path
    assert_response :success

    sign_in users(:ana)
    get new_post_path
    assert_response :forbidden
  end

  test "o select de tipo oferece só o que a policy libera" do
    sign_in users(:escritor_user)
    get new_post_path
    assert_select "select[name='post[tipo]'] option", text: "Blog", count: 1
    assert_select "select[name='post[tipo]'] option", text: "Notícia", count: 0

    sign_in users(:jornalista_user)
    get new_post_path
    assert_select "select[name='post[tipo]'] option", text: "Notícia", count: 1
    assert_select "select[name='post[tipo]'] option", text: "Blog", count: 0

    sign_in users(:membro_user)
    get new_post_path
    assert_select "select[name='post[tipo]'] option", count: 2, message: "a liga escreve os dois"
  end

  test "quem só escreve um tipo tem o tipo no formulário, mesmo com o select travado" do
    sign_in users(:jornalista_user)
    get new_post_path

    assert_select "select[name=?][disabled=disabled]", "post[tipo]"
    # select disabled NÃO é enviado no POST. Sem este hidden o tipo chegaria nil,
    # a validação do enum devolveria 422 e o autor levaria um erro num campo que
    # ele nem podia mexer — sem nada na tela explicando o quê.
    assert_select "input[type=hidden][name=?][value=?]", "post[tipo]", "noticia"
  end

  test "criar pelo formulário HTML redireciona e nasce rascunho (RN-02)" do
    sign_in users(:escritor_user)

    post posts_path, params: {
      post: { tipo: "blog", titulo: "Escrito no site", formato: "markdown",
              corpo_markdown: "## Oi\n\ntexto **em markdown**" }
    }, headers: { "Accept" => "text/html" }

    criado = Post.order(:id).last
    assert_redirected_to edit_post_path(criado)
    assert_equal "rascunho", criado.status
    assert_match "<strong>em markdown</strong>", criado.corpo.to_s
  end

  # Perder o texto de alguém a cada erro de validação seria a pior falha
  # possível numa tela de escrita longa.
  test "erro de validação no formulário volta a tela preenchida, não um JSON" do
    sign_in users(:escritor_user)

    post posts_path, params: { post: { tipo: "blog", titulo: "", corpo_markdown: "não posso perder isto" } },
                     headers: { "Accept" => "text/html" }

    assert_response :unprocessable_entity
    assert_select "form.escrita-form"
    assert_select "textarea[name='post[corpo_markdown]']", text: /não posso perder isto/
  end

  # Regressão de um bug que nenhum teste de resposta pegaria, porque o HTML
  # estava "certo": o editor ficava dentro de um <label>. O controle rotulado de
  # um label é o primeiro descendente rotulável — o input hidden do Action Text
  # não é, o <trix-editor> não é, mas os <button> que o Trix injeta na barra SÃO.
  # Cada clique no texto ativava o label e mandava o foco para o botão "Negrito":
  # não dava para digitar, e a formatação não aplicava porque a seleção se perdia.
  test "o editor rico não fica dentro de um <label>" do
    sign_in users(:membro_user)
    get new_post_path

    assert_select "trix-editor"
    assert_select "label trix-editor", count: 0,
                  message: "<label> rouba o foco do editor para o primeiro botão da barra"
    assert_select "div.editor-rico trix-editor", message: "a barra e o editor vivem na mesma moldura"
  end

  # Sem o trix.css a barra sai sem ícone nenhum: eles são SVG embutidos nos
  # ::before dos botões, e só esse arquivo os define. O layout público não o
  # carrega — quem pede é o formulário.
  test "a tela pública de escrita carrega o CSS do Trix" do
    sign_in users(:membro_user)

    get new_post_path
    assert_select "head link[rel=stylesheet][href*=?]", "trix"

    get posts_path, headers: { "Accept" => "text/html" }
    assert_select "head link[rel=stylesheet][href*=?]", "trix", count: 0,
                  message: "o editor não pode pesar nas telas que não editam nada"
  end

  test "editar novidade alheia é 403, mesmo tendo papel de escrita" do
    sign_in users(:escritor_user)
    get edit_post_path(posts(:rascunho_do_membro))
    assert_response :forbidden

    sign_in users(:membro_user)
    get edit_post_path(posts(:rascunho_do_membro))
    assert_response :success
  end

  test "submeter pelo formulário HTML manda para a fila e volta para Minhas novidades" do
    sign_in users(:membro_user)
    post submeter_post_path(posts(:rascunho_do_membro)), headers: { "Accept" => "text/html" }

    assert_redirected_to meus_posts_path
    assert posts(:rascunho_do_membro).reload.em_aprovacao?
  end

  test "meus responde HTML sem perder o contrato JSON" do
    sign_in users(:membro_user)

    get meus_posts_path, headers: { "Accept" => "text/html" }
    assert_response :success
    assert_select ".escrita-item-titulo", text: "Rascunho de notícia"

    get meus_posts_path, as: :json
    assert_equal 2, response.parsed_body["posts"].size
  end

  test "o botão de escrever aparece em /novidades só para quem pode escrever" do
    get posts_path, headers: { "Accept" => "text/html" }
    assert_select "a[href=?]", new_post_path, count: 0, message: "anônimo não escreve"

    sign_in users(:ana)
    get posts_path, headers: { "Accept" => "text/html" }
    assert_select "a[href=?]", new_post_path, count: 0, message: "comunidade não escreve"

    sign_in users(:jornalista_user)
    get posts_path, headers: { "Accept" => "text/html" }
    assert_select "a[href=?]", new_post_path
  end

  # A feature não pode ter virado uma porta lateral para o painel.
  test "escritor e jornalista continuam de fora de /painel" do
    [ users(:escritor_user), users(:jornalista_user) ].each do |usuario|
      sign_in usuario
      get painel_posts_path
      assert_redirected_to root_path
    end
  end
end
