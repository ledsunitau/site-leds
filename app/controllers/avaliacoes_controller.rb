# Avaliações de produto (#LOJA4). Login obrigatório; só quem comprou avalia
# (regra no model). Conteúdo do usuário — sem edição pela gestão.
class AvaliacoesController < ApplicationController
  before_action :authenticate_user!

  def create
    produto = Produto.find(params[:produto_id])
    avaliacao = produto.avaliacoes.build(avaliacao_params.merge(autor: current_user))

    respond_to do |format|
      if avaliacao.save
        format.html { redirect_to produto_path(produto), notice: "Avaliação publicada. Valeu! ⭐" }
        format.json { render json: avaliacao.card_json, status: :created }
      else
        msg = avaliacao.errors.full_messages.to_sentence
        format.html { redirect_to produto_path(produto), alert: msg }
        format.json { render_invalido(avaliacao) }
      end
    end
  end

  private

  def avaliacao_params
    params.require(:avaliacao).permit(:nota, :comentario)
  end
end
