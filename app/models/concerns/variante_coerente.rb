# Para linhas que apontam para (produto, variante) — item de carrinho, reserva
# (e itens_pedido no checkout). Garante que a variante EXISTE e pertence ÀQUELE
# produto. Sem isto: variante de outro produto passa (item forjável), e um
# variante_id inexistente vai até o banco e volta InvalidForeignKey (500) em vez
# do contrato de 422.
module VarianteCoerente
  extend ActiveSupport::Concern

  included do
    validate :variante_pertence_ao_produto
  end

  private

  def variante_pertence_ao_produto
    return if variante_id.blank?

    if variante.nil? || variante.produto_id != produto_id
      errors.add(:variante, "não pertence a este produto")
    end
  end
end
