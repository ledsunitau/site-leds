# Ações pela gestão (RF-ACO): projetos, eventos e artigos, em qualquer status.
# A rota pública lista só publicadas — rascunho e arquivada não tinham tela.
#
# A montagem do detalhe delegado e das coleções aninhadas vem do concern
# EscritaDeAcao, o MESMO que o AcoesController usa: o que cada tipo aceita e a
# semântica de coleção não podem divergir entre a API e o painel.
class Painel::AcoesController < Painel::BaseController
  include EscritaDeAcao

  POR_PAGINA = 30

  before_action :carregar_acao, only: %i[edit update destroy]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @tipo = filtro(:tipo)
    @status = filtro(:status)
    @busca = filtro(:busca)

    escopo = Acao.includes(:detalhe, :criador, :ideia, thumbnail_attachment: :blob)
                 .order(created_at: :desc)
    escopo = escopo.where(detalhe_type: @tipo) if @tipo
    escopo = escopo.where(status: @status) if @status
    if @busca
      escopo = escopo.where(Acao.arel_table[:titulo].matches("%#{Acao.sanitize_sql_like(@busca)}%"))
    end

    @acoes = paginar(escopo, por_pagina: POR_PAGINA)
    @por_status = Acao.group(:status).count
    @por_tipo = Acao.group(:detalhe_type).count
  end

  def new
    @tipo = EscritaDeAcao::TIPOS_DETALHE.key?(params[:tipo]) ? params[:tipo] : "projeto"
    # ?ideia_id vem de "criar ação a partir desta ideia" (tela de Ideias): o
    # idealizador só pode ser fixado agora, na criação (RF-ACO-07).
    @acao = Acao.new(status: "rascunho", ideia_id: params[:ideia_id].presence)
    @detalhe = EscritaDeAcao::TIPOS_DETALHE.fetch(@tipo).new
    carregar_opcoes
  end

  def edit
    @tipo = @acao.detalhe_type.underscore
    @detalhe = @acao.detalhe
    carregar_opcoes
  end

  def create
    authorize Acao
    autoriza_arquivamento!(Acao)

    criador = member_atual
    return if criador.nil?

    @tipo = params.require(:acao)[:tipo].to_s
    unless EscritaDeAcao::TIPOS_DETALHE.key?(@tipo)
      return redirect_to painel_acoes_path, status: :see_other, alert: "Escolha o tipo da ação."
    end

    acao = nil
    ActiveRecord::Base.transaction do
      acao = Acao.create!(acao_params.merge(detalhe: montar_detalhe(@tipo), criador: criador))
      atualiza_parceiros(acao)
    end

    voltar_para edit_painel_acao_path(acao), "“#{acao.titulo}” criada."
  end

  def update
    authorize @acao
    autoriza_arquivamento!(@acao)

    ActiveRecord::Base.transaction do
      @acao.update!(acao_params)
      atualizar_detalhe(@acao)
      atualiza_parceiros(@acao)
    end

    voltar_para edit_painel_acao_path(@acao), "“#{@acao.titulo}” atualizada."
  end

  # Destruir SEMPRE pela Acao: o dependent: :destroy do delegated_type leva o
  # detalhe junto (não há FK em detalhe_id — a integridade é da aplicação).
  def destroy
    authorize @acao
    titulo = @acao.titulo
    @acao.destroy!
    voltar_para painel_acoes_path, "“#{titulo}” apagada."
  end

  private

  def carregar_acao
    @acao = Acao.includes(:detalhe).find(params[:id])
  end

  def carregar_opcoes
    @membros = Member.includes(:user).order("users.name").references(:user)
    @tecnologias = Tecnologia.order(:nome)
    @temas = Tema.order(:nome)
    @congressos = Congresso.order(:nome)
    @parceiros = Parceiro.order(:nome)
    # idealizador só sai de ideia APROVADA e que ainda não virou ação (o model
    # valida os dois; o select evita oferecer o que seria recusado)
    @ideias = Ideia.aprovada.where.missing(:acao).order(:titulo)
  end
end
