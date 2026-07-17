# Parceiros (RF-PAR): vitrine pública dos ativos (RF-PAR-01), perfil com as
# ações apoiadas (RF-PAR-02) e edição pela gestão ou pela conta vinculada
# (RF-PAR-05). Criar parceiro direto é da gestão; o caminho normal é converter
# um lead (Admin::ParceriaLeadsController#converter).
class ParceirosController < ApplicationController
  before_action :authenticate_user!, only: %i[create update]

  def index
    authorize Parceiro

    # público vê só a vitrine (ativos); a gestão filtra por status para operar
    parceiros = if policy(Parceiro).gerenciar? && filtro(:status)
      Parceiro.where(status: filtro(:status))
    else
      Parceiro.ativos
    end

    render json: { parceiros: paginar(parceiros.order(:nome)).map(&:card_json) }
  end

  def show
    parceiro = Parceiro.find(params[:id])
    authorize parceiro

    # RF-PAR-02: só as ações publicadas. Cards no mesmo formato do índice de
    # ações — é literalmente o motivo de Projeto#card_json morar no model
    # ("a vitrine de parceiros também renderiza estes cards").
    acoes = paginar(parceiro.acoes.publicadas.order(created_at: :desc))
                   .includes(:detalhe, thumbnail_attachment: :blob)

    render json: parceiro.card_json.merge(
      descricao: parceiro.descricao,
      acoes: acoes.map do |acao|
        {
          id: acao.id,
          tipo: acao.detalhe_type,
          titulo: acao.titulo,
          thumbnail_url: FotoUrl.para(acao.thumbnail),
          detalhe: acao.detalhe&.card_json
        }
      end
    )
  end

  def create
    authorize Parceiro
    parceiro = Parceiro.create!(parceiro_params)
    render json: parceiro.card_json, status: :created
  end

  def update
    parceiro = Parceiro.find(params[:id])
    authorize parceiro

    parceiro.update!(parceiro_params_permitidos(parceiro))
    render json: parceiro.card_json
  end

  private

  def parceiro_params
    params.expect(parceiro: %i[nome descricao site_url status user_id])
  end

  # A conta vinculada edita a própria vitrine, mas não se promove: status e
  # user_id (quem é o dono) são da gestão. O gate é gerenciar? — pendurar isso
  # em create? acoplaria o privilégio a outra pergunta, que pode ser afrouxada.
  def parceiro_params_permitidos(parceiro)
    return parceiro_params if policy(parceiro).gerenciar?

    params.expect(parceiro: %i[nome descricao site_url])
  end
end
