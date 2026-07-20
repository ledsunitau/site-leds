# Endereços de entrega do próprio usuário (RF-LOJ-04, envio). Escopo em
# current_user é a autz (RN-17). Usados como destino da cotação e da etiqueta.
class EnderecosController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: { enderecos: current_user.enderecos.order(:id).map(&:card_json) }
  end

  def create
    endereco = current_user.enderecos.create!(endereco_params)
    render json: endereco.card_json, status: :created
  end

  def update
    endereco = current_user.enderecos.find(params[:id])
    endereco.update!(endereco_params)
    render json: endereco.card_json
  end

  def destroy
    current_user.enderecos.find(params[:id]).destroy!
    head :no_content
  end

  private

  def endereco_params
    params.expect(endereco: %i[cep logradouro numero complemento bairro cidade uf])
  end
end
