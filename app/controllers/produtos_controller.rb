# Catálogo da loja (RF-LOJ-01). Tudo aqui exige login — inclusive LER (RN-17:
# padrão exclusivo da loja). Cadastro/edição é de membro da liga para cima e
# fica auditado (RF-LOJ-09/RN-13, via PaperTrail no model).
class ProdutosController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize Produto

    # sem includes(:variantes): o card do índice não as renderiza (só o show).
    # imagem_attachment fica: FotoUrl.para precisa do attachment e do blob.
    produtos = Produto.includes(imagem_attachment: :blob).order(:nome)
    # cliente vê a vitrine (ativos); quem cadastra filtra por status para operar
    produtos = if policy(Produto).create? && filtro(:status)
      produtos.where(status: filtro(:status))
    else
      produtos.ativos
    end
    produtos = produtos.where(modo_venda: filtro(:modo_venda)) if filtro(:modo_venda)

    render json: { produtos: paginar(produtos).map(&:card_json) }
  end

  def show
    produto = Produto.includes(:variantes, imagem_attachment: :blob).find(params[:id])
    authorize produto

    render json: produto_json(produto)
  end

  def create
    authorize Produto

    criador = exigir_member!
    return if criador.nil?

    produto = nil
    ActiveRecord::Base.transaction do
      produto = Produto.create!(produto_params.merge(criador: criador))
      substitui_variantes(produto)
    end

    render json: produto_json(produto), status: :created
  end

  def update
    produto = Produto.find(params[:id])
    authorize produto

    ActiveRecord::Base.transaction do
      produto.update!(produto_params)
      substitui_variantes(produto)
    end

    render json: produto_json(produto)
  end

  private

  # require+permit, não expect: expect levanta quando NENHUM escalar esperado
  # veio, e um PATCH que só troca as variantes é legítimo (400 seria mentira).
  def produto_params
    params.require(:produto).permit(:nome, :descricao, :modo_venda, :preco,
                                    :preco_promocional, :status, :quantidade_alvo, :imagem)
  end

  # Semântica de editor: a lista enviada é o estado final. Chave ausente = não
  # mexer; [] = esvaziar de propósito — por isso permit+key?, não expect (que
  # exigiria a chave e daria 400 num PATCH parcial).
  #
  # DIFF por id, não destroy_all+recria (que é o que substitui_colecao faz nas
  # ações): lá as coleções são folhas, aqui NÃO — itens_carrinho/reservas/
  # itens_pedido vão apontar para variante_id. Recriar trocaria o id a cada
  # edição de estoque e derrubaria os carrinhos de todo mundo.
  # destroy_all nas removidas, nunca delete_all: cada remoção vira versão (RN-13).
  def substitui_variantes(produto)
    return unless params.require(:produto).key?(:variantes)

    bruto = params[:produto][:variantes]
    # permit dropa em silêncio o que não é objeto: variantes: ["M","G"] viraria
    # [] e apagaria a lista inteira respondendo 200. Lista malformada é 422.
    unless bruto.is_a?(Array) && bruto.all? { |v| v.is_a?(ActionController::Parameters) }
      produto.errors.add(:variantes, "precisa ser uma lista de objetos")
      raise ActiveRecord::RecordInvalid.new(produto)
    end

    enviadas = params.require(:produto).permit(variantes: %i[id nome sku estoque])[:variantes]
    mantidos = enviadas.filter_map { |v| v[:id].presence }
    produto.variantes.where.not(id: mantidos).destroy_all

    enviadas.each do |attrs|
      atributos = attrs.except(:id)
      if attrs[:id].present?
        produto.variantes.find(attrs[:id]).update!(atributos)
      else
        produto.variantes.create!(atributos)
      end
    end
  end

  def produto_json(produto)
    produto.card_json.merge(
      descricao: produto.descricao,
      quantidade_alvo: produto.quantidade_alvo,
      variantes: produto.variantes.map(&:card_json)
    )
  end
end
