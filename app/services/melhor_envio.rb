require "net/http"

# Intermediador de frete (RF-LOJ-11): cota Correios (PAC/SEDEX) e transportadoras,
# gera etiqueta (declaração de conteúdo, sem NF) e rastreia. Cadastrado com CPF de
# um responsável da liga (§8) — a liga não tem CNPJ. Token e dados do remetente
# vêm do ENV; sem token, configurado? é false e o frete responde "indisponível".
#
# Sandbox x produção pelo ENV (MELHOR_ENVIO_SANDBOX). A cotação NÃO precisa de
# CPF (só CEP+peso+dimensões); etiqueta/rastreio precisam do cadastro completo.
module MelhorEnvio
  class ErroFrete < StandardError; end

  module_function

  def configurado? = ENV["MELHOR_ENVIO_TOKEN"].present?

  def sandbox? = ENV["MELHOR_ENVIO_SANDBOX"].to_s != "false"

  # Cota o frete do CEP de origem (liga) ao destino, para os itens dados.
  # Devolve [{ servico_id, transportadora, servico, preco, prazo }] — só as
  # opções válidas (o Melhor Envio devolve erro por opção quando não atende).
  def cotar(cep_destino, itens)
    produtos = itens.map { |item| produto_payload(item) }
    corpo = {
      from: { postal_code: cep_origem },
      to: { postal_code: so_digitos(cep_destino) },
      products: produtos
    }
    requisitar(Net::HTTP::Post, "/api/v2/me/shipment/calculate", corpo).filter_map do |opcao|
      next if opcao["error"].present? || opcao["price"].blank?

      {
        servico_id: opcao["id"],
        transportadora: opcao.dig("company", "name"),
        servico: opcao["name"],
        preco: BigDecimal(opcao["price"].to_s),
        prazo: opcao["delivery_time"]
      }
    end
  end

  # Fluxo de compra da etiqueta (pós-pagamento): carrinho → checkout (paga com
  # saldo ME) → gerar → rastrear. Devolve { ref:, codigo: }. ref é o id do envio
  # no ME (melhor_envio_ref); codigo é o rastreamento.
  def comprar_etiqueta(pedido)
    destinatario = destinatario_payload(pedido)
    raise ErroFrete, "CPF do remetente e do destinatário não podem ser iguais" unless
      cpf_remetente != destinatario[:document]

    item = requisitar(Net::HTTP::Post, "/api/v2/me/cart", {
      service: pedido.servico_frete,
      from: remetente_payload,
      to: destinatario,
      products: pedido.itens.map { |i| produto_payload(i) }
    })
    ref = item.fetch("id")

    requisitar(Net::HTTP::Post, "/api/v2/me/shipment/checkout", { orders: [ ref ] })
    requisitar(Net::HTTP::Post, "/api/v2/me/shipment/generate", { orders: [ ref ] })
    dados = requisitar(Net::HTTP::Post, "/api/v2/me/shipment/tracking", { orders: [ ref ] })

    { ref: ref, codigo: dados.dig(ref, "tracking") }
  end

  # Situação atual de um envio já postado. Devolve o status cru do ME
  # (ex.: "posted", "delivered") para o RastreioUpdateJob decidir.
  def rastrear(ref)
    requisitar(Net::HTTP::Post, "/api/v2/me/shipment/tracking", { orders: [ ref ] }).dig(ref, "status")
  end

  # --- payloads / config ---

  def produto_payload(item)
    v = item.variante
    raise ErroFrete, "\"#{item.produto.nome}\" está sem peso/dimensões para frete." unless v&.dimensoes_para_frete?

    # carrinho (ItemCarrinho) não tem snapshot: usa o preço atual; pedido usa o subtotal.
    valor = item.respond_to?(:subtotal) ? item.subtotal : item.produto.preco_atual * item.quantidade
    {
      id: v.id.to_s, quantity: item.quantidade, insurance_value: valor.to_f,
      weight: v.peso.to_f, height: v.altura.to_f, width: v.largura.to_f, length: v.comprimento.to_f
    }
  end

  def remetente_payload
    {
      name: ENV["MELHOR_ENVIO_NOME_REMETENTE"], document: cpf_remetente,
      postal_code: cep_origem, address: ENV["MELHOR_ENVIO_LOGRADOURO_REMETENTE"],
      number: ENV["MELHOR_ENVIO_NUMERO_REMETENTE"], city: ENV["MELHOR_ENVIO_CIDADE_REMETENTE"],
      state_abbr: ENV["MELHOR_ENVIO_UF_REMETENTE"]
    }
  end

  # ponytail: o CPF do destinatário ainda não é coletado (não há campo no cadastro
  # nem no checkout — chega com o form real/Figma). Como o ME EXIGE o documento do
  # destinatário, a compra AUTOMÁTICA de etiqueta não funciona até isso existir; o
  # caminho funcional no lançamento é o despacho manual da gestão (Admin#enviar).
  # Upgrade: capturar o CPF do comprador no envio → etiqueta automática liga.
  def destinatario_payload(pedido)
    endereco = pedido.endereco
    {
      name: pedido.comprador&.name, document: nil,
      postal_code: endereco.cep, address: endereco.logradouro, number: endereco.numero,
      city: endereco.cidade, state_abbr: endereco.uf
    }
  end

  def cep_origem = so_digitos(ENV["MELHOR_ENVIO_CEP_ORIGEM"])
  def cpf_remetente = ENV["MELHOR_ENVIO_CPF_REMETENTE"].to_s.presence
  def so_digitos(cep) = cep.to_s.gsub(/\D/, "")

  def requisitar(klasse, caminho, corpo)
    raise ErroFrete, "Melhor Envio não configurado" unless configurado?

    uri = URI("#{base_url}#{caminho}")
    req = klasse.new(uri)
    req["Authorization"] = "Bearer #{ENV['MELHOR_ENVIO_TOKEN']}"
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req.body = corpo.to_json

    resposta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
      http.request(req)
    end
    raise ErroFrete, "Melhor Envio respondeu #{resposta.code}" unless resposta.is_a?(Net::HTTPSuccess)

    JSON.parse(resposta.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
    # sem timeout, um ME travado penduraria o worker/conexão indefinidamente
    raise ErroFrete, "Falha de rede com o Melhor Envio (#{e.class})"
  end

  def base_url = sandbox? ? "https://sandbox.melhorenvio.com.br" : "https://www.melhorenvio.com.br"

  private_class_method :requisitar, :base_url, :remetente_payload, :destinatario_payload,
                       :produto_payload, :cep_origem, :cpf_remetente
end
