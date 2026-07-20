# Monta o pedido (RF-LOJ-04): do carrinho (estoque) ou da conversão de uma
# reserva (sob demanda, RF-LOJ-07). Tudo em transação — se o estoque não bate,
# nada é criado. NÃO inicia pagamento: quem faz isso é Pagamentos.iniciar, para
# a falha do gateway não desfazer o pedido/estoque.
module Checkout
  class Erro < StandardError; end
  class Vazio < Erro; end
  class SemSaldo < Erro; end
  class Indisponivel < Erro; end

  module_function

  # Estoque: carrinho → pedido. Congela o preço (snapshot), baixa o estoque com
  # lock (RN: "só compra quando há saldo") e esvazia o carrinho. entrega escolhe
  # retirada (padrão) ou envio com frete cotado no servidor (RF-LOJ-04/11).
  def do_carrinho(user, entrega: {})
    carrinho = user.carrinho
    raise Vazio, "Carrinho vazio." if carrinho.nil? || carrinho.itens.empty?

    # cota o frete ANTES da transação: é chamada externa (lenta) e não pode
    # segurar a transação/lock de estoque aberta esperando o gateway.
    atributos = atributos_entrega(user, carrinho, entrega)

    Pedido.transaction do
      pedido = Pedido.create!(comprador: user, status: "aguardando_pagamento", **atributos)
      total = carrinho.itens.includes(:produto, :variante).sum do |item|
        adicionar_item!(pedido, item.produto, item.variante, item.quantidade, baixar_estoque: true)
      end
      pedido.update!(total: total + (pedido.frete_valor || 0))
      carrinho.itens.destroy_all
      pedido
    end
  end

  # Retirada (padrão) ou envio. No envio RE-COTA no servidor e usa o preço
  # autoritativo do gateway — nunca o frete_valor que o cliente mandaria (senão
  # dava para pagar frete R$0). A opção escolhida vem por servico_id da cotação.
  def atributos_entrega(user, carrinho, entrega)
    return { tipo_entrega: "retirada" } unless entrega[:tipo_entrega].to_s == "envio"

    endereco = user.enderecos.find_by(id: entrega[:endereco_id])
    raise Indisponivel, "Endereço de entrega inválido." if endereco.nil?

    opcao = Frete.cotar(endereco.cep, carrinho.itens.includes(:variante))
                 .find { |o| o[:servico_id].to_s == entrega[:servico_id].to_s }
    raise Indisponivel, "Opção de frete inválida ou indisponível." if opcao.nil?

    {
      tipo_entrega: "envio", endereco: endereco, transportadora: opcao[:transportadora],
      servico_frete: opcao[:servico_id].to_s, frete_valor: opcao[:preco], prazo_estimado: opcao[:prazo]
    }
  end

  # Sob demanda: reserva → pedido. Não baixa estoque (é feito sob demanda); a
  # reserva só vira 'convertida' quando o pagamento é aprovado (Pedido#marcar_pago!).
  def da_reserva(reserva)
    Pedido.transaction do
      reserva.lock! # trava a linha: dois "pagar" concorrentes não criam 2 pedidos
      raise Erro, "Reserva não está ativa." unless reserva.ativa?
      raise Erro, "Reserva já tem pedido." if reserva.pedido_id.present?

      pedido = Pedido.create!(comprador: reserva.user, tipo_entrega: "retirada", status: "aguardando_pagamento")
      total = adicionar_item!(pedido, reserva.produto, reserva.variante, reserva.quantidade, baixar_estoque: false)
      pedido.update!(total: total)
      reserva.update!(pedido: pedido)
      pedido
    end
  end

  # cria o item com snapshot de preço e (opcional) baixa o estoque; devolve o subtotal
  def adicionar_item!(pedido, produto, variante, quantidade, baixar_estoque:)
    raise Indisponivel, "\"#{produto.nome}\" não está disponível." unless produto.ativo?

    baixar_estoque!(produto, variante, quantidade) if baixar_estoque
    preco = produto.preco_atual
    pedido.itens.create!(produto: produto, variante: variante, quantidade: quantidade, preco_unitario: preco)
    preco * quantidade
  end

  # lock na variante: sem ele, dois checkouts do último item ambos leem saldo
  # suficiente e vendem além do estoque (oversell). No modo estoque o saldo mora
  # na variante — sem variante não há como validar, então exige uma (senão o item
  # passaria sem checagem = oversell).
  def baixar_estoque!(produto, variante, quantidade)
    raise Indisponivel, "Selecione uma variação de \"#{produto.nome}\"." if variante.nil?

    variante.with_lock do
      if variante.estoque < quantidade
        raise SemSaldo, "\"#{produto.nome}\": só há #{variante.estoque} em estoque."
      end
      variante.decrement!(:estoque, quantidade)
    end
  end
end
