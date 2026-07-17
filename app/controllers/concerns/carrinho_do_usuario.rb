# O carrinho do usuário logado (RF-LOJ-02). Compartilhado por CarrinhoController
# e ItensCarrinhoController — os dois operam sempre o carrinho de current_user,
# nunca o de outro, então o escopo É a autorização (login basta, RN-17).
module CarrinhoDoUsuario
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  # Um carrinho por usuário (índice único em user_id): a corrida entre dois
  # requests do mesmo usuário vira RecordNotUnique — com_upsert_concorrente
  # reexecuta e o find acha o que o outro criou.
  def carrinho_atual
    @carrinho_atual ||= com_upsert_concorrente { Carrinho.find_or_create_by!(user: current_user) }
  end

  def carrinho_json(carrinho)
    itens = carrinho.itens.includes(produto: { imagem_attachment: :blob }, variante: {}).to_a
    {
      total_itens: itens.sum(&:quantidade), # dos itens já carregados, sem SUM extra
      itens: itens.map(&:card_json)
    }
  end
end
