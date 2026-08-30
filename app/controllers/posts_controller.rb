# Novidades (RF-NOV): posts de notícia/blog com fila de aprovação (RN-02),
# corpo rico (Action Text), histórico de versões (RF-NOV-07) e anúncio no
# Discord ao publicar (RF-NOV-11, via callback do model).
class PostsController < ApplicationController
  before_action :authenticate_user!, except: %i[index show ultimas]

  # Registrado DEPOIS do handler do ApplicationController, então ganha nas duas
  # (no Rails o último rescue_from compatível é o que roda). Lá a resposta é
  # JSON — contrato da API, e continua valendo aqui para tudo que não é HTML.
  # Na tela de escrita, porém, redirecionar ou devolver JSON jogaria fora o texto
  # que a pessoa acabou de digitar; então o formulário volta preenchido, com os
  # erros e 422.
  rescue_from ActiveRecord::RecordInvalid do |e|
    if request.format.html?
      @post = e.record
      render(@post.persisted? ? :edit : :new, status: :unprocessable_entity)
    else
      render_invalido(e.record)
    end
  end

  POR_PAGINA = 6 # mesmo número que a paginação client-side mostrava

  def index
    authorize Post

    # JSON é o contrato da API (default); a página HTML (carrossel + grid) só
    # sai quando o browser pede text/html — mesmo padrão de Ações/Membros.
    respond_to do |format|
      format.json do
        posts = base_scope
        posts = posts.where(tipo: filtro(:tipo)) if filtro(:tipo)
        # público vê publicados; a gestão filtra por status para operar a fila de
        # aprovação (mesmo idioma do índice de ações)
        posts = if policy(Post).aprovar? && filtro(:status)
          posts.where(status: filtro(:status)).order(updated_at: :desc)
        else
          posts.publicados.order(published_at: :desc)
        end
        render json: { posts: paginar(posts).map { |p| post_json(p) } }
      end

      # Página pública. Tipo (chips), busca e página são parâmetros de URL
      # resolvidos AQUI — antes vinha a tabela inteira e o Stimulus escondia o
      # resto, então a busca só enxergava o que já estava na tela.
      #
      # O carrossel é consulta PRÓPRIA, não @posts.first(3): ele é "as 3 mais
      # recentes", não "as 3 primeiras do filtro atual" — senão filtrar por Blog
      # trocaria o carrossel junto, e ele nem está dentro do frame.
      format.html do
        publicados = base_scope.publicados.order(published_at: :desc)

        @tipo = Post::TIPOS.include?(filtro(:tipo)) ? filtro(:tipo) : nil
        @busca = filtro(:q)
        escopo = publicados
        escopo = escopo.where(tipo: @tipo) if @tipo
        # caller E titulo: o card mostra `caller` quando existe (ver posts/_card),
        # então buscar só em titulo erraria justamente o texto que está na tela.
        escopo = buscar_por(escopo, :caller, :titulo)

        @pagina = pagina_atual
        @total_paginas = total_de_paginas(escopo, por_pagina: POR_PAGINA)
        @posts = paginar(escopo, por_pagina: POR_PAGINA).to_a

        # Só na carga completa: o frame não redesenha o carrossel.
        @carrossel = turbo_frame_request? ? [] : publicados.limit(3).to_a

        render_em_frame "posts/lista"
      end
    end
  end

  # Posts do próprio autor, em qualquer status (rascunhos, rejeitados…).
  def meus
    authorize Post, :index?

    posts = base_scope.where(autor: current_user).order(updated_at: :desc)

    respond_to do |format|
      format.json { render json: { posts: paginar(posts).map { |p| post_json(p) } } }
      format.html do
        @pagina = pagina_atual
        @total_paginas = total_de_paginas(posts, por_pagina: 20) # 20 = padrão do paginar
        @posts = paginar(posts).to_a
      end
    end
  end

  # --- tela de escrita fora do painel (RF-NOV-04) ---
  #
  # Existe porque escritor e jornalista NÃO entram em /painel (só diretoria e
  # presidência passam pelo exigir_gestao!), e sem tela a permissão da PostPolicy
  # não valia nada. A gestão continua com a tela do painel; esta é a mesma
  # máquina de estados, com a moldura do site público.

  def new
    # tipo inicial = o primeiro que a policy deixa: escritor cai em blog,
    # jornalista em notícia, e a liga em notícia (a ordem de Post::TIPOS).
    # helpers.: a lista mora no HomeHelper, que é quem a view também consulta —
    # duas cópias divergiriam no dia em que a policy mudasse.
    @post = Post.new(tipo: helpers.tipos_de_novidade_permitidos.first, formato: "rico")
    authorize @post
  end

  def edit
    @post = Post.find(params[:id])
    authorize @post, :update?
  end

  # RF-INI-07: últimas notícias publicadas para a landing (cache TTL — RNF-01;
  # FotoUrl mantém as URLs relativas, seguras para cachear; o model expira a
  # chave quando uma notícia sai do ar).
  def ultimas
    authorize Post, :index?

    payload = Rails.cache.fetch("posts/ultimas", expires_in: 5.minutes) do
      posts = base_scope.publicados.noticia.order(published_at: :desc).limit(6)
      { posts: posts.map { |p| post_json(p) } }
    end

    render json: payload
  end

  def show
    post = Post.find(params[:id])
    authorize post

    respond_to do |format|
      format.json { render json: post_json(post, completo: true) }
      # Página da novidade: banner + autor/data + título + corpo + relacionadas
      # (mesmo tipo, mais recentes; cai em quaisquer publicados se não houver).
      format.html do
        @post = post
        relacionadas = base_scope.publicados.where.not(id: post.id)
        @relacionadas = relacionadas.where(tipo: post.tipo).order(published_at: :desc).limit(3).to_a
        @relacionadas = relacionadas.order(published_at: :desc).limit(3).to_a if @relacionadas.empty?
      end
    end
  end

  def create
    post = Post.new(post_params.merge(autor: current_user))
    authorize post

    post.save!
    # O JSON é contrato de API e não muda de forma nenhuma; o HTML é a tela nova
    # e responde com redirect porque o Turbo descarta resposta de formulário que
    # não seja redirect (303 — ver Painel::BaseController#voltar_para).
    respond_to do |format|
      format.json { render json: post_json(post, completo: true), status: :created }
      format.html { redirect_to edit_post_path(post), notice: "Rascunho criado.", status: :see_other }
    end
  end

  def update
    post = Post.find(params[:id])
    # lock: sem ele, um update do autor correndo contra o aprovar da diretoria
    # gravaria conteúdo novo num post que acabou de virar publicado, sem o
    # reset do RN-02 (o callback leria o status velho)
    post.with_lock do
      post.assign_attributes(post_params)
      # depois do assign: cobre dono/gestor E a capacidade sobre o tipo novo
      # (escritor não pode transformar o próprio blog em notícia)
      authorize post
      post.save!
    end

    respond_to do |format|
      format.json { render json: post_json(post, completo: true) }
      format.html { redirect_to edit_post_path(post), notice: mensagem_de_edicao(post), status: :see_other }
    end
  end

  def destroy
    post = Post.find(params[:id])
    authorize post

    post.destroy!
    head :no_content
  end

  # --- fluxo de aprovação (RN-02): transições e anúncio vivem no model ---

  def submeter
    post = Post.find(params[:id])
    authorize post

    post.submeter!

    respond_to do |format|
      format.json { render json: post_json(post, completo: true) }
      format.html do
        redirect_to meus_posts_path, status: :see_other,
                    notice: "“#{post.titulo}” foi para a fila de aprovação. A gestão revisa e publica."
      end
    end
  end

  def aprovar
    post = Post.find(params[:id])
    authorize post

    aprovador = exigir_member!
    return if aprovador.nil?

    post.aprovar!(aprovador)
    render json: post_json(post, completo: true)
  end

  def rejeitar
    post = Post.find(params[:id])
    authorize post

    post.rejeitar!
    render json: post_json(post, completo: true)
  end

  # RF-NOV-07: histórico de versões — as colunas do post E o corpo rico
  # (Action Text vive em tabela própria; sem as versões dele o histórico
  # perderia justamente o conteúdo).
  def versoes
    post = Post.find(params[:id])
    authorize post

    versoes = versoes_leves(post.versions) + versoes_leves(post.rich_text_corpo&.versions)
    versoes = versoes.sort_by { |v| [ v.created_at, v.id ] }

    render json: { versoes: versoes.map { |v| versao_json(v) } }
  end

  private

  # status NUNCA entra por aqui: publicar é aprovar (fluxo próprio) — senão
  # qualquer autor se auto-publica (RN-02).
  def post_params
    params.require(:post).permit(:tipo, :titulo, :subtitulo, :caller, :corpo, :thumbnail,
                                 :formato, :corpo_markdown)
  end

  # RF-NOV-06: qualquer edição de conteúdo publicado volta para a fila. O model
  # faz isso sozinho — a tela precisa DIZER, senão parece que a edição sumiu.
  # (mesma mensagem do Painel::PostsController, para quem escreve nos dois lugares)
  def mensagem_de_edicao(post)
    if post.saved_change_to_status? && post.em_aprovacao?
      "Salvo. Como já estava publicada, voltou para a fila de aprovação (RN-02)."
    else
      "Alterações salvas."
    end
  end

  def base_scope
    # emblema_nome do autor: os cards pintam o nome com a pintura que ele veste
    # (RF-EMB), e sem o preload seria uma consulta por card
    Post.includes(thumbnail_attachment: :blob, autor: :emblema_nome)
  end

  # sem a coluna object (snapshot completo por linha, nunca lida aqui):
  # um post muito editado tornaria a resposta megabytes por nada
  def versoes_leves(versions)
    return [] if versions.nil?

    versions.select(:id, :item_type, :event, :whodunnit, :created_at, :object_changes)
  end

  def post_json(post, completo: false)
    json = {
      id: post.id,
      tipo: post.tipo,
      titulo: post.titulo,
      subtitulo: post.subtitulo,
      caller: post.caller,
      status: post.status,
      autor: post.autor && { id: post.autor.id, name: post.autor.name },
      published_at: post.published_at,
      thumbnail_url: FotoUrl.para(post.thumbnail)
    }
    return json unless completo

    json[:corpo] = post.corpo&.to_s
    json[:approved_at] = post.approved_at
    json
  end

  def versao_json(versao)
    {
      id: versao.id,
      item: versao.item_type == "Post" ? "post" : "corpo",
      event: versao.event,
      whodunnit: versao.whodunnit,
      created_at: versao.created_at,
      mudancas: mudancas_da_versao(versao)
    }
  end
end
