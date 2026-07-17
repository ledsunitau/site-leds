# Itens do carrinho (RF-LOJ-02). Adicionar o mesmo (produto, variante) SOMA a
# quantidade em vez de duplicar (o índice único é por carrinho+produto+variante).
class ItensCarrinhoController < ApplicationController
  include CarrinhoDoUsuario

  def create
    dados = params.expect(item: %i[produto_id variante_id quantidade])
    # quantidade a adicionar tem de ser positiva: sem isso um "-1" faria o
    # endpoint de ADICIONAR na verdade DIMINUIR um item existente
    a_somar = dados.key?(:quantidade) ? dados[:quantidade].to_i : 1
    if a_somar < 1
      return render json: { errors: [ "Quantidade a adicionar deve ser positiva." ] },
                    status: :unprocessable_entity
    end

    produto = Produto.find(dados[:produto_id]) # 404 se não existe — fora do retry
    carrinho = carrinho_atual # cria o carrinho aqui (tem o seu próprio upsert)

    # SÓ o find-or-save do item no retry: a corrida (double-click) vira
    # RecordNotUnique e reexecuta, agora achando o item do outro request e
    # somando. Aninhar com o upsert do carrinho fazia o bloco rodar 2x e somar
    # em dobro.
    com_upsert_concorrente do
      item = carrinho.itens.find_or_initialize_by(
        produto_id: produto.id, variante_id: dados[:variante_id].presence
      )
      item.produto = produto
      # base 0 no item NOVO: a coluna tem default 1, então find_or_initialize já
      # o traz com quantidade 1 — somar em cima daria 1+a_somar no primeiro add
      base = item.new_record? ? 0 : item.quantidade
      item.quantidade = base + a_somar
      item.save!
    end

    render json: carrinho_json(carrinho), status: :created
  end

  def update
    item = carrinho_atual.itens.find(params[:id])
    item.update!(params.expect(item: %i[quantidade]))

    render json: carrinho_json(carrinho_atual)
  end

  def destroy
    carrinho_atual.itens.find(params[:id]).destroy!
    head :no_content
  end
end
