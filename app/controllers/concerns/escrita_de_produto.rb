# Escrita de Produtos (RF-LOJ): campos aceitos e o diff de variantes.
#
# Extraído do ProdutosController quando o painel passou a cadastrar produto por
# formulário. As duas telas divergem só na RESPOSTA — o que se aceita e como as
# variantes são reconciliadas tem de valer igual, senão a API e o painel
# escrevem produtos diferentes.
#
# CORREÇÃO trazida junto: `categoria_id` e `destaque` não estavam na lista
# permitida. Nenhum produto podia receber categoria pelo app (o filtro do
# catálogo lia uma coluna que só o seed escrevia) e os destaques da home da loja
# só saíam de db/seeds.rb.
module EscritaDeProduto
  extend ActiveSupport::Concern

  CAMPOS_VARIANTE = %i[id nome sku estoque peso altura largura comprimento].freeze

  private

  # require+permit, não expect: expect levanta quando NENHUM escalar esperado
  # veio, e um PATCH que só troca as variantes é legítimo (400 seria mentira).
  def produto_params
    params.require(:produto).permit(:nome, :descricao, :modo_venda, :preco,
                                    :preco_promocional, :status, :quantidade_alvo,
                                    :categoria_id, :destaque, :imagem)
  end

  # Semântica de editor: a lista enviada é o estado final. Chave ausente = não
  # mexer; [] = esvaziar de propósito — por isso permit+key?, não expect (que
  # exigiria a chave e daria 400 num PATCH parcial).
  #
  # DIFF por id, não destroy_all+recria (que é o que substitui_colecao faz nas
  # ações): lá as coleções são folhas, aqui NÃO — itens_carrinho/reservas/
  # itens_pedido apontam para variante_id. Recriar trocaria o id a cada edição
  # de estoque e derrubaria os carrinhos de todo mundo.
  # destroy_all nas removidas, nunca delete_all: cada remoção vira versão (RN-13).
  def substitui_variantes(produto)
    return unless params.require(:produto).key?(:variantes)

    enviadas = variantes_enviadas(produto)
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

  # A API manda array de objetos; o formulário manda hash indexado
  # ("0" => {...}). Normaliza para lista e descarta a linha-marcador em branco
  # (que existe só para a chave chegar quando o gestor apaga todas as linhas).
  def variantes_enviadas(produto)
    bruto = params[:produto][:variantes]
    bruto = bruto.values if bruto.respond_to?(:values) && !bruto.is_a?(Array)

    # permit dropa em silêncio o que não é objeto: variantes: ["M","G"] viraria
    # [] e apagaria a lista inteira respondendo 200. Lista malformada é 422.
    unless bruto.is_a?(Array) && bruto.all? { |v| v.is_a?(ActionController::Parameters) }
      produto.errors.add(:variantes, "precisa ser uma lista de objetos")
      raise ActiveRecord::RecordInvalid.new(produto)
    end

    lista = params.require(:produto).permit(variantes: CAMPOS_VARIANTE)[:variantes]
    lista = lista.values if lista.respond_to?(:values) && !lista.is_a?(Array)
    lista.reject { |v| v[:nome].blank? && v[:id].blank? }
  end
end
