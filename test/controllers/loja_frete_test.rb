require "test_helper"

# Endereços, cotação de frete, checkout de envio e transições de gestão (RF-LOJ-04/11).
class LojaFreteFluxoTest < ActionDispatch::IntegrationTest
  # --- endereços do usuário ---

  test "endereços exigem login" do
    get enderecos_path
    assert_response :redirect
  end

  test "CRUD de endereço do próprio usuário" do
    sign_in users(:ana)

    assert_difference "users(:ana).enderecos.count", 1 do
      post enderecos_path, params: { endereco: {
        cep: "12010-000", logradouro: "Rua A", numero: "1", cidade: "Taubate", uf: "sp"
      } }
    end
    assert_response :created
    id = response.parsed_body["id"]
    assert_equal "12010000", response.parsed_body["cep"], "CEP normalizado só com dígitos"
    assert_equal "SP", response.parsed_body["uf"], "UF em maiúsculas"

    patch endereco_path(id), params: { endereco: { logradouro: "Rua B", cep: "12010000", cidade: "Taubate", uf: "SP" } }
    assert_response :success
    assert_equal "Rua B", response.parsed_body["logradouro"]

    assert_difference "users(:ana).enderecos.count", -1 do
      delete endereco_path(id)
    end
  end

  test "CEP inválido é 422" do
    sign_in users(:ana)
    post enderecos_path, params: { endereco: { cep: "123", logradouro: "R", cidade: "T", uf: "SP" } }
    assert_response :unprocessable_entity
  end

  test "não vejo nem apago endereço de outro usuário" do
    alheio = enderecos(:casa_da_ana)
    sign_in users(:membro_user)
    delete endereco_path(alheio)
    assert_response :not_found
    assert Endereco.exists?(alheio.id)
  end

  # --- cotação de frete ---

  test "cotar frete exige login" do
    post frete_cotar_path, params: { cep: "12010000" }
    assert_response :redirect
  end

  test "cotar com carrinho vazio é 422" do
    sign_in users(:membro_user)
    post frete_cotar_path, params: { cep: "12010000" }
    assert_response :unprocessable_entity
  end

  test "cotar devolve as opções do gateway" do
    sign_in users(:ana) # tem carrinho com camiseta_m (com dimensões)
    opcoes = [ { servico_id: 1, transportadora: "Correios", servico: "PAC", preco: BigDecimal("22.30"), prazo: 6 } ]
    stub_frete(opcoes) do
      post frete_cotar_path, params: { cep: "12010000" }
    end
    assert_response :success
    assert_equal 1, response.parsed_body["opcoes"].size
    assert_equal "22.3", response.parsed_body["opcoes"].first["preco"]
  end

  test "cotar responde 503 se o gateway falhar" do
    sign_in users(:ana)
    orig = Frete.method(:cotar)
    Frete.define_singleton_method(:cotar) { |*_| raise MelhorEnvio::ErroFrete, "fora do ar" }
    post frete_cotar_path, params: { cep: "12010000" }
    assert_response :service_unavailable
  ensure
    Frete.define_singleton_method(:cotar, orig)
  end

  # --- checkout de envio ---

  test "checkout de envio grava o frete e devolve a URL de pagamento" do
    sign_in users(:ana)
    opcoes = [ { servico_id: 1, transportadora: "Correios", servico: "PAC", preco: BigDecimal("25.00"), prazo: 5 } ]

    stub_frete(opcoes) do
      stub_mp_criar("https://mp/pay/x") do
        post checkout_path, params: { entrega: {
          tipo_entrega: "envio", endereco_id: enderecos(:casa_da_ana).id, servico_id: 1
        } }
      end
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "https://mp/pay/x", body["pagamento_url"]
    assert_equal "envio", body["pedido"]["tipo_entrega"]
    assert_equal "25.0", body["pedido"]["frete_valor"]
  end

  test "checkout ignora frete_valor/preco forjado pelo cliente (servidor re-cota)" do
    sign_in users(:ana)
    opcoes = [ { servico_id: 1, transportadora: "Correios", servico: "PAC", preco: BigDecimal("25.00"), prazo: 5 } ]
    stub_frete(opcoes) do
      stub_mp_criar("u") do
        post checkout_path, params: { entrega: {
          tipo_entrega: "envio", endereco_id: enderecos(:casa_da_ana).id, servico_id: 1,
          frete_valor: "0.01", preco: "0.01" # ignorados: não estão no permit
        } }
      end
    end
    assert_response :created
    assert_equal "25.0", response.parsed_body["pedido"]["frete_valor"], "preço vem do servidor"
  end

  test "entrega como escalar não quebra (cai em retirada)" do
    sign_in users(:ana)
    stub_mp_criar("u") { post checkout_path, params: { entrega: "foo" } }
    assert_response :created
    assert_equal "retirada", response.parsed_body["pedido"]["tipo_entrega"]
  end

  test "checkout de envio com endereço inexistente é 422 (não 404)" do
    sign_in users(:ana)
    post checkout_path, params: { entrega: { tipo_entrega: "envio", endereco_id: 999_999, servico_id: 1 } }
    assert_response :unprocessable_entity
  end

  # --- transições de gestão ---

  test "gestão marca em produção; não-gestão é 403" do
    pedido = pedido_pago_envio
    sign_in users(:ana) # comunidade
    post em_producao_admin_pedido_path(pedido)
    assert_response :forbidden

    sign_in users(:diretor) # diretoria
    post em_producao_admin_pedido_path(pedido)
    assert_response :success
    assert pedido.reload.em_producao?
  end

  test "gestão registra envio manual com código de rastreio" do
    pedido = pedido_pago_envio
    sign_in users(:diretor)
    post enviar_admin_pedido_path(pedido), params: { rastreamento_codigo: "BR555" }
    assert_response :success
    assert pedido.reload.enviado?
    assert_equal "BR555", pedido.rastreamento_codigo
  end

  test "gestão confirma entrega manual (fecha envio despachado à mão)" do
    pedido = pedido_pago_envio
    sign_in users(:diretor)
    post enviar_admin_pedido_path(pedido), params: { rastreamento_codigo: "BR7" }
    post entregar_admin_pedido_path(pedido)
    assert_response :success
    assert pedido.reload.entregue?
  end

  test "transição inválida via endpoint admin é 422" do
    pedido = pedido_pago_envio # pago → entregue pula etapas
    sign_in users(:diretor)
    post entregar_admin_pedido_path(pedido)
    assert_response :unprocessable_entity
  end

  private

  def pedido_pago_envio
    Pedido.create!(comprador: users(:ana), tipo_entrega: "envio", endereco: enderecos(:casa_da_ana),
                   status: "pago", servico_frete: "1", frete_valor: 20, total: 120)
  end

  def stub_frete(opcoes)
    orig = Frete.method(:cotar)
    Frete.define_singleton_method(:cotar) { |*_| opcoes }
    yield
  ensure
    Frete.define_singleton_method(:cotar, orig)
  end

  def stub_mp_criar(init_point)
    orig = MercadoPago.method(:criar_preferencia)
    MercadoPago.define_singleton_method(:criar_preferencia) { |_pedido| { id: "p", init_point: init_point } }
    yield
  ensure
    MercadoPago.define_singleton_method(:criar_preferencia, orig)
  end
end
