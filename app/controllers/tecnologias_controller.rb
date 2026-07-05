# Catálogo reutilizável de tecnologias (stack dos projetos, RF-ACO-03).
class TecnologiasController < ApplicationController
  before_action :authenticate_user!, only: :create

  def index
    authorize Tecnologia

    render json: { tecnologias: Tecnologia.order(:nome).with_attached_icone.map(&:card_json) }
  end

  def create
    authorize Tecnologia

    tecnologia = Tecnologia.create!(params.expect(tecnologia: [ :nome, :icone ]))
    render json: tecnologia.card_json, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalido(e.record)
  end
end
