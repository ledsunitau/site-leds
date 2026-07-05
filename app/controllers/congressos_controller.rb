# Congressos reutilizáveis (CICTED etc.) para apresentações de artigos.
class CongressosController < ApplicationController
  before_action :authenticate_user!, only: :create

  def index
    authorize Congresso

    render json: { congressos: Congresso.order(:nome).map(&:card_json) }
  end

  def create
    authorize Congresso

    congresso = Congresso.create!(params.expect(congresso: [ :nome ]))
    render json: congresso.card_json, status: :created
  end
end
