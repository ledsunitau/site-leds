# Catálogo pela gestão (RF-LOJ-01/08/09/10). Cadastro, preço, promoção, modo de
# venda, destaque da home e variantes (estoque + peso/dimensões do frete).
#
# A escrita reusa o concern EscritaDeProduto — o mesmo da API — para que o diff
# de variantes por id não seja reimplementado: variante_id é referenciado por
# carrinho, reserva e item de pedido, então recriar linha derrubaria carrinho
# alheio.
class Painel::ProdutosController < Painel::BaseController
  include EscritaDeProduto

  POR_PAGINA = 40

  before_action :carregar_produto, only: %i[edit update]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)
    @modo = filtro(:modo_venda)
    @busca = filtro(:busca)

    escopo = Produto.includes(:categoria, :variantes, imagem_attachment: :blob).order(:nome)
    escopo = escopo.where(status: @status) if @status
    escopo = escopo.where(modo_venda: @modo) if @modo
    if @busca
      escopo = escopo.where(Produto.arel_table[:nome].matches("%#{Produto.sanitize_sql_like(@busca)}%"))
    end

    @produtos = paginar(escopo, por_pagina: POR_PAGINA)
    @por_status = Produto.group(:status).count
  end

  def new
    @produto = Produto.new(modo_venda: "estoque", status: "ativo")
    carregar_opcoes
  end

  def edit
    carregar_opcoes
  end

  def create
    @produto = Produto.new
    @produto.assign_attributes(produto_params_com_galeria(@produto))
    authorize @produto
    criador = member_atual
    return if criador.nil?

    @produto.criador = criador
    ActiveRecord::Base.transaction do
      @produto.save!
      substitui_variantes(@produto)
    end

    voltar_para edit_painel_produto_path(@produto), "“#{@produto.nome}” cadastrado."
  end

  def update
    authorize @produto

    # Marcar indisponível dispara o trigger que limpa carrinhos e cancela
    # reservas (RN-11), e o model notifica os reservantes — por isso passa pelo
    # caminho ActiveRecord, nunca por update_column.
    ActiveRecord::Base.transaction do
      @produto.update!(produto_params_com_galeria(@produto))
      substitui_variantes(@produto)
    end

    voltar_para edit_painel_produto_path(@produto), "“#{@produto.nome}” atualizado."
  end

  private

  # preload da galeria: o formulário desenha uma miniatura por foto, e sem isto
  # é uma consulta de blob por foto na tela de edição.
  def carregar_produto
    @produto = Produto.includes(galeria_attachments: :blob).find(params[:id])
  end

  def carregar_opcoes
    @categorias = Categoria.order(:nome)
  end
end
