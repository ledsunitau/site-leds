# Temas pré-definidos do artigo (catálogo via seeds; gestão vem no admin).
class TemasController < ApplicationController
  def index
    authorize Tema

    render json: { temas: Tema.order(:nome).with_attached_icone.map(&:card_json) }
  end
end
