# Categorias de produto (RF-LOJ-01). Agrupam a vitrine no catálogo expandido.
# Não havia NENHUMA rota de escrita: a única forma de criar categoria era o seed.
class Painel::CategoriasController < Painel::BaseController
  def index
    @pendencias = PainelMetricas.new.pendencias
    @categorias = Categoria.order(:nome)
    @contagem = Produto.group(:categoria_id).count
  end

  def create
    Categoria.create!(categoria_params)
    voltar_para painel_categorias_path, "Categoria criada."
  end

  def update
    Categoria.find(params[:id]).update!(categoria_params)
    voltar_para painel_categorias_path, "Categoria renomeada."
  end

  # A FK é ON DELETE SET NULL (produtos.categoria_id) — apagar não leva produto
  # junto, só os desagrupa. Como é reversível (basta reatribuir), não bloqueio
  # como em diretorias, mas aviso quantos produtos ficam sem categoria.
  def destroy
    categoria = Categoria.find(params[:id])
    afetados = categoria.produtos.count
    categoria.destroy!

    voltar_para painel_categorias_path,
                afetados.zero? ? "Categoria removida." : "Categoria removida — #{afetados} produto(s) ficaram sem categoria."
  end

  private

  def categoria_params = params.expect(categoria: [ :nome ])
end
