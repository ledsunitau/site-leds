# Novidades pela gestão (RF-NOV). Até aqui escrever um post exigia a API: não
# havia NENHUMA tela de criação no site, e o Trix nem estava instalado.
#
# A máquina de estados é do model (RN-02): editar publicado devolve para
# em_aprovacao sozinho (Post#retornar_para_aprovacao), e publicar é aprovar!.
class Painel::PostsController < Painel::BaseController
  POR_PAGINA = 30

  before_action :carregar_post, only: %i[edit update destroy versoes]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)
    @tipo = filtro(:tipo)
    @busca = filtro(:busca)

    escopo = Post.includes(:autor, :aprovador).with_attached_thumbnail.order(updated_at: :desc)
    escopo = escopo.where(status: @status) if @status
    escopo = escopo.where(tipo: @tipo) if @tipo
    if @busca
      escopo = escopo.where(Post.arel_table[:titulo].matches("%#{Post.sanitize_sql_like(@busca)}%"))
    end

    @posts = paginar(escopo, por_pagina: POR_PAGINA)
    @contagem = Post.group(:status).count
  end

  def new
    @post = Post.new(tipo: "noticia")
  end

  def edit; end

  def create
    @post = Post.new(post_params.merge(autor: current_user))
    authorize @post
    @post.save!
    voltar_para edit_painel_post_path(@post), "Rascunho criado."
  end

  def update
    authorize @post
    @post.update!(post_params)
    voltar_para edit_painel_post_path(@post), mensagem_de_edicao
  end

  def destroy
    authorize @post
    titulo = @post.titulo
    @post.destroy!
    voltar_para painel_posts_path, "“#{titulo}” apagada."
  end

  # RF-NOV-07: histórico de versões com o diff, reusando o mesmo formatador do
  # posts#versoes e do /admin/audits — mascarar um atributo vale nos três.
  def versoes
    @versoes = @post.versions.order(id: :desc).limit(50).map do |versao|
      { versao: versao, autor: User.find_by(id: versao.whodunnit), mudancas: mudancas_da_versao(versao) }
    end
  end

  # Manda o rascunho para a fila (RN-02). Publicar não é feito aqui: quem
  # escreveu não se aprova — a liberação é na tela de Aprovações.
  def submeter
    post = Post.find(params[:id])
    authorize post, :update?
    post.submeter!
    voltar_para painel_aprovacoes_path, "“#{post.titulo}” foi para a fila de aprovação."
  end

  private

  def carregar_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.expect(post: [ :tipo, :titulo, :subtitulo, :caller, :corpo, :thumbnail ])
  end

  # RF-NOV-06: qualquer edição de conteúdo publicado volta para a fila. O model
  # faz isso sozinho — a tela precisa DIZER, senão parece que a edição sumiu.
  def mensagem_de_edicao
    if @post.saved_change_to_status? && @post.em_aprovacao?
      "Salvo. Como já estava publicada, voltou para a fila de aprovação (RN-02)."
    else
      "Alterações salvas."
    end
  end
end
