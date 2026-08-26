# Catálogo da loja (RF-LOJ-01). Tudo aqui exige login — inclusive LER (RN-17:
# padrão exclusivo da loja). Cadastro/edição é de membro da liga para cima e
# fica auditado (RF-LOJ-09/RN-13, via PaperTrail no model).
class ProdutosController < ApplicationController
  # Campos aceitos e diff de variantes — compartilhados com o painel de
  # gestão (Painel::ProdutosController), que cadastra por formulário.
  include EscritaDeProduto

  before_action :authenticate_user!
  # loja desligada pela gestão → comprador vê "indisponível"; quem opera segue.
  before_action :loja_disponivel!, only: %i[index show todos]

  POR_PAGINA = 8 # mesmo número que a paginação client-side mostrava

  # Produto#preco_atual (preco_promocional || preco) em SQL. O filtro de faixa
  # tem que comparar contra o preço que a pessoa VÊ — usar `preco` deixaria um
  # item em promoção fora da faixa que ele visualmente ocupa.
  PRECO_ATUAL = Arel::Nodes::NamedFunction.new(
    "COALESCE", [ Produto.arel_table[:preco_promocional], Produto.arel_table[:preco] ]
  ).freeze

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

  # #LOJA2: catálogo expandido. Categoria, busca, faixa de preço, promoção e
  # página são parâmetros de URL resolvidos AQUI. Antes o servidor mandava TODOS
  # os produtos e o Stimulus escondia todos menos 8 — o pior dos dois mundos:
  # payload de catálogo inteiro para mostrar uma página.
  def todos
    authorize Produto, :index?

    ativos = Produto.ativos
    @teto = (ativos.maximum(PRECO_ATUAL) || 100).ceil

    @cat = filtro(:cat)&.to_i
    @busca = filtro(:q)
    @preco_min = preco_do_filtro(:preco_min, 0)
    @preco_max = preco_do_filtro(:preco_max, @teto)
    @promo = filtro(:promo) == "1"

    escopo = ativos.order(:nome)
    escopo = escopo.where(categoria_id: @cat) if @cat&.positive?
    escopo = buscar_por(escopo, :nome)
    escopo = escopo.where(PRECO_ATUAL.gteq(@preco_min)) if @preco_min.positive?
    escopo = escopo.where(PRECO_ATUAL.lteq(@preco_max)) if @preco_max < @teto
    escopo = escopo.em_promocao if @promo

    @pagina = pagina_atual
    @total = escopo.count
    @total_paginas = [ (@total.to_f / POR_PAGINA).ceil, 1 ].max
    @produtos = paginar(escopo.includes(:categoria, :variantes, imagem_attachment: :blob),
                        por_pagina: POR_PAGINA)

    @categorias = Categoria.order(:nome)
    # contagem por categoria numa query só (evita N COUNTs na sidebar)
    @contagem_categoria = ativos.group(:categoria_id).count

    render_em_frame "produtos/lista"
  end

  def show
    produto = Produto.includes(:variantes, imagem_attachment: :blob).find(params[:id])
    authorize produto

    respond_to do |format|
      format.json { render json: produto_json(produto) }
      format.html do
        # #LOJA3/#LOJA4: detalhe + avaliações (cliente pagina)
        @produto = produto
        # os dois emblemas do autor: o cosmético pinta o nome, o destaque vira o
        # ícone ao lado. Sem o preload seria uma consulta por avaliação.
        @avaliacoes = produto.avaliacoes.recentes
                             .includes(autor: %i[emblema_nome emblema_destaque])
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

  # Preço vindo da query string. Fora da faixa [0, teto] ou não-numérico cai no
  # padrão — o slider é público e o valor vai direto para um comparador SQL.
  def preco_do_filtro(chave, padrao)
    bruto = filtro(chave)
    return padrao if bruto.blank? || !bruto.match?(/\A\d+(\.\d+)?\z/)

    bruto.to_d.clamp(0, @teto)
  end

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

  def produto_json(produto)
    produto.card_json.merge(
      descricao: produto.descricao,
      quantidade_alvo: produto.quantidade_alvo,
      variantes: produto.variantes.map(&:card_json)
    )
  end
end
