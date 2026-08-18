# RF-LOJ-02: o carrinho do usuário logado.
class CarrinhoController < ApplicationController
  include CarrinhoDoUsuario

  def show
    respond_to do |format|
      format.json { render json: carrinho_json(carrinho_atual) }
      format.html do
        @itens = carrinho_atual.itens
                               .includes(produto: { imagem_attachment: :blob }, variante: {})
        @total = @itens.sum { |i| i.produto.preco_atual * i.quantidade }
        @modo_pagamento = Setting.modo_pagamento
      end
    end
  end
end
