# Ações (RF-ACO): listagem pública com filtro por tipo, detalhe, e
# criação/edição por membros+ (auditada — RN-13/RNF-09). Nesta branch o único
# tipo delegado é Projeto; Evento e Artigo estendem `detalhe_json`,
# `montar_detalhe` e `atualizar_detalhe` na próxima branch.
class AcoesController < ApplicationController
  before_action :authenticate_user!, only: %i[create update]

  def index
    authorize Acao

    acoes = Acao.includes(:detalhe, thumbnail_attachment: :blob).order(created_at: :desc)
    acoes = acoes.where(detalhe_type: filtro(:tipo)) if filtro(:tipo)
    # público vê só publicadas; membros+ podem filtrar por status (rascunhos etc.)
    acoes = if policy(Acao).create? && filtro(:status)
      acoes.where(status: filtro(:status))
    else
      acoes.publicadas
    end

    render json: { acoes: acoes.map { |a| acao_json(a) } }
  end

  def show
    acao = Acao.includes(:detalhe, thumbnail_attachment: :blob).find(params[:id])
    authorize acao

    render json: acao_json(acao, completo: true)
  end

  def create
    authorize Acao
    autoriza_arquivamento!(Acao)

    criador = current_user.member
    if criador.nil?
      return render json: { errors: [ "Seu usuário ainda não tem perfil de membro cadastrado." ] },
                    status: :unprocessable_entity
    end
    unless params.require(:acao)[:projeto].is_a?(ActionController::Parameters)
      return render json: { errors: [ "Informe os dados do projeto em acao[projeto]." ] },
                    status: :unprocessable_entity
    end

    acao = nil
    ActiveRecord::Base.transaction do
      projeto = Projeto.create!(projeto_params)
      atualiza_stack_e_contribuicoes(projeto)
      acao = Acao.create!(acao_params.merge(detalhe: projeto, criador: criador))
    end

    render json: acao_json(acao, completo: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalido(e.record)
  end

  def update
    acao = Acao.find(params[:id])
    authorize acao
    autoriza_arquivamento!(acao)

    ActiveRecord::Base.transaction do
      acao.update!(acao_params)
      if acao.projeto?
        acao.detalhe.update!(projeto_params) if params[:acao]&.key?(:projeto)
        atualiza_stack_e_contribuicoes(acao.detalhe)
      end
    end

    render json: acao_json(acao, completo: true)
  rescue ActiveRecord::RecordInvalid => e
    render_invalido(e.record)
  end

  # RF-INI-02: compilado de ações em destaque para a landing (cache TTL,
  # mesmo esquema do grafo — RNF-01).
  def destaque
    authorize Acao, :index?

    # atenção: do/end aqui se ligaria ao render, não ao fetch (bloco perdido)
    payload = Rails.cache.fetch("acoes/destaque", expires_in: 5.minutes) do
      acoes = Acao.publicadas.order(created_at: :desc).limit(6)
                  .includes(:detalhe, thumbnail_attachment: :blob)
      { acoes: acoes.map { |a| acao_json(a) } }
    end

    render json: payload
  end

  private

  def acao_params
    params.require(:acao).permit(:titulo, :descricao, :status, :thumbnail)
  end

  def projeto_params
    params.require(:acao)
          .permit(projeto: [ :link, :repo_url, :hospedagem, :situacao, :data_finalizacao ])
          .fetch(:projeto, {})
  end

  # Stack e contribuições são substituídas por inteiro quando enviadas
  # (semântica de editor: o payload é o estado final desejado). destroy_all,
  # não delete_all: cada remoção precisa virar versão no PaperTrail.
  def atualiza_stack_e_contribuicoes(projeto)
    dados = params.require(:acao).permit(tecnologia_ids: [], contribuicoes: [ :member_id, :papel ])

    if dados.key?(:tecnologia_ids)
      begin
        projeto.tecnologia_ids = dados[:tecnologia_ids]
      rescue ActiveRecord::RecordNotFound
        projeto.errors.add(:base, "stack contém tecnologia inexistente")
        raise ActiveRecord::RecordInvalid.new(projeto)
      end
    end

    if dados.key?(:contribuicoes)
      projeto.contribuicoes.destroy_all
      dados[:contribuicoes].each { |c| projeto.contribuicoes.create!(c) }
    end
  end

  # Entrar OU sair de "arquivada" é gestão (diretoria+), não edição comum —
  # vale para create (nascer arquivada) e update.
  def autoriza_arquivamento!(alvo)
    novo = params.dig(:acao, :status)
    return if novo.blank?

    atual = alvo.is_a?(Acao) ? alvo.status : nil
    return if novo == atual

    authorize(alvo, :arquivar?) if novo == "arquivada" || atual == "arquivada"
  end

  def acao_json(acao, completo: false)
    {
      id: acao.id,
      tipo: acao.detalhe_type,
      titulo: acao.titulo,
      descricao: acao.descricao,
      status: acao.status,
      thumbnail_url: FotoUrl.para(acao.thumbnail),
      detalhe: detalhe_json(acao.detalhe, completo: completo)
    }
  end

  # Único ponto de despacho por tipo — Evento/Artigo adicionam `when` aqui.
  # No card: "em dev" ou a data de finalização (RF-ACO-03).
  def detalhe_json(detalhe, completo:)
    case detalhe
    when Projeto
      json = { situacao: detalhe.situacao, data_finalizacao: detalhe.data_finalizacao }
      if completo
        json[:link] = detalhe.link
        json[:repo_url] = detalhe.repo_url
        json[:hospedagem] = detalhe.hospedagem
        json[:stack] = detalhe.tecnologias.with_attached_icone.map(&:card_json)
        json[:contribuicoes] = detalhe.contribuicoes.includes(member: :user).map do |c|
          { member_id: c.member_id, name: c.member.name, papel: c.papel }
        end
      end
      json
    else
      {}
    end
  end
end
