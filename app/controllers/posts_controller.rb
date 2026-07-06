# Novidades (RF-NOV): posts de notícia/blog com fila de aprovação (RN-02),
# corpo rico (Action Text), histórico de versões (RF-NOV-07) e anúncio no
# Discord ao publicar (RF-NOV-11, via callback do model).
class PostsController < ApplicationController
  before_action :authenticate_user!, except: %i[index show ultimas]

  def index
    authorize Post

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

  # Posts do próprio autor, em qualquer status (rascunhos, rejeitados…).
  def meus
    authorize Post, :index?

    posts = base_scope.where(autor: current_user).order(updated_at: :desc)
    render json: { posts: paginar(posts).map { |p| post_json(p) } }
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

    render json: post_json(post, completo: true)
  end

  def create
    post = Post.new(post_params.merge(autor: current_user))
    authorize post

    post.save!
    render json: post_json(post, completo: true), status: :created
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

    render json: post_json(post, completo: true)
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
    render json: post_json(post, completo: true)
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
    params.require(:post).permit(:tipo, :titulo, :subtitulo, :caller, :corpo, :thumbnail)
  end

  def base_scope
    Post.includes(:autor, thumbnail_attachment: :blob)
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
