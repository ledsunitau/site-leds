# Cotação de frete do carrinho do usuário para um CEP (RF-LOJ-11). Cacheada
# (Frete, por CEP+peso+dimensões) e com throttle (rack_attack) porque bate numa
# API externa limitada (§7.3). Só do próprio usuário logado (RN-17).
class FretesController < ApplicationController
  before_action :authenticate_user!

  def cotar
    carrinho = current_user.carrinho
    if carrinho.nil? || carrinho.itens.empty?
      return render json: { errors: [ "Carrinho vazio." ] }, status: :unprocessable_entity
    end

    opcoes = Frete.cotar(params.require(:cep), carrinho.itens.includes(:variante, :produto))
    render json: { opcoes: opcoes }
  rescue MelhorEnvio::ErroFrete => e
    render json: { errors: [ e.message ] }, status: :service_unavailable
  end
end
