# RF-LOJ-02: o carrinho do usuário logado.
class CarrinhoController < ApplicationController
  include CarrinhoDoUsuario

  def show
    render json: carrinho_json(carrinho_atual)
  end
end
