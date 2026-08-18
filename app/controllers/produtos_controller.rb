# Catálogo da loja (RF-LOJ-01). Tudo aqui exige login — inclusive LER (RN-17:
# padrão exclusivo da loja). Cadastro/edição é de membro da liga para cima e
# fica auditado (RF-LOJ-09/RN-13, via PaperTrail no model).
class ProdutosController < ApplicationController
  before_action :authenticate_user!
  # loja desligada pela gestão → comprador vê "indisponível"; quem opera segue.
  before_action :loja_disponivel!, only: %i[index show todos]

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

    respond_to do |format|
      format.json { render json: { produtos: paginar(produtos).map(&:card_json) } }
      format.html do
        # #LOJA: 3 banners de destaque + 6 mais vendidos (sem filtro)
        @destaques = Produto.destaques.ativos.includes(:variantes, imagem_attachment: :blob).limit(3)
        @mais_vendidos = Produto.mais_vendidos(6)
      end
    end
  end

  # #LOJA2: catálogo expandido — todos os ativos + categorias para o filtro
  # lateral. Filtro/paginação são no cliente (Stimulus loja), como em Ações.
  def todos
    authorize Produto, :index?

    @produtos = Produto.ativos.includes(:categoria, :variantes, imagem_attachment: :blob).order(:nome)
    @categorias = Categoria.order(:nome)
    # contagem por categoria numa query só (evita N COUNTs na sidebar)
    @contagem_categoria = Produto.ativos.group(:categoria_id).count
  end

  def show
    produto = Produto.includes(:variantes, imagem_attachment: :blob).find(params[:id])
    authorize produto

    respond_to do |format|
      format.json { render json: produto_json(produto) }
      format.html do
        # #LOJA3/#LOJA4: detalhe + avaliações (cliente pagina)
        @produto = produto
        @avaliacoes = produto.avaliacoes.recentes.includes(:autor)
        @pode_avaliar = produto.comprado_por?(current_user)
        @ja_avaliou = produto.avaliacoes.exists?(user_id: current_user.id)
      end
    end
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

  # Loja desligada (Setting): o comprador vê "indisponível"; quem cadastra/edita
  # (membro da liga) segue enxergando para operar. Barra só a navegação; carrinho
  # e checkout têm o próprio guard.
  def loja_disponivel!
    return if Setting.loja_ativa? || policy(Produto).create?

    respond_to do |format|
      format.json { render json: { errors: [ "Loja indisponível no momento." ] }, status: :service_unavailable }
      format.html { render "produtos/indisponivel", status: :service_unavailable }
    end
  end

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
