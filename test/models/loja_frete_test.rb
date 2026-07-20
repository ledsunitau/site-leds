require "test_helper"

# Frete (RF-LOJ-11): cotação Melhor Envio, checkout de envio, máquina de
# fulfillment do pedido e os jobs de etiqueta/rastreio.
class LojaFreteTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # --- MelhorEnvio.cotar ---

  test "cotar normaliza as opções válidas e descarta as com erro" do
    resposta = [
      { "id" => 1, "name" => "PAC", "price" => "23.50", "delivery_time" => 5, "company" => { "name" => "Correios" } },
      { "id" => 2, "name" => "SEDEX", "price" => "45.00", "delivery_time" => 2, "company" => { "name" => "Correios" } },
      { "id" => 3, "name" => "X", "error" => "CEP inválido" }
    ]
    opcoes = stub_requisitar(resposta) { MelhorEnvio.cotar("12010-000", [ item_frete ]) }

    assert_equal 2, opcoes.size
    assert_equal BigDecimal("23.50"), opcoes.first[:preco]
    assert_equal "Correios", opcoes.first[:transportadora]
    assert_equal 1, opcoes.first[:servico_id]
  end

  test "cotar recusa item sem peso/dimensões" do
    sem_dim = item_frete(variantes(:camiseta_g)) # camiseta_g não tem dimensões
    erro = assert_raises(MelhorEnvio::ErroFrete) do
      stub_requisitar([]) { MelhorEnvio.cotar("12010000", [ sem_dim ]) }
    end
    assert_match(/dimens/i, erro.message)
  end

  test "comprar_etiqueta exige CPF de remetente (fail-closed)" do
    sem_cpf_remetente do
      assert_raises(MelhorEnvio::ErroFrete) { MelhorEnvio.comprar_etiqueta(pedido_pago_envio) }
    end
  end

  # --- checkout de envio ---

  test "checkout de envio re-cota no servidor e ignora o preço do cliente" do
    opcoes = [ { servico_id: 1, transportadora: "Correios", servico: "PAC", preco: BigDecimal("25.00"), prazo: 5 } ]

    pedido = stub_frete(opcoes) do
      Checkout.do_carrinho(users(:ana),
        entrega: { tipo_entrega: "envio", endereco_id: enderecos(:casa_da_ana).id, servico_id: 1 })
    end

    assert pedido.envio?
    assert_equal enderecos(:casa_da_ana), pedido.endereco
    assert_equal BigDecimal("25.00"), pedido.frete_valor
    assert_equal "Correios", pedido.transportadora
    assert_equal BigDecimal("124.80"), pedido.total, "itens (99,80) + frete (25,00)"
  end

  test "checkout de envio com opção de frete inexistente é erro" do
    stub_frete([]) do
      assert_raises(Checkout::Indisponivel) do
        Checkout.do_carrinho(users(:ana),
          entrega: { tipo_entrega: "envio", endereco_id: enderecos(:casa_da_ana).id, servico_id: 99 })
      end
    end
  end

  test "checkout de retirada continua sem frete" do
    pedido = Checkout.do_carrinho(users(:ana))
    assert pedido.retirada?
    assert_nil pedido.frete_valor
    assert_equal BigDecimal("99.80"), pedido.total
  end

  # --- máquina de fulfillment ---

  test "transições pago → em_producao → enviado → entregue" do
    pedido = pedido_pago_envio
    pedido.marcar_em_producao!
    assert pedido.em_producao?
    pedido.marcar_enviado!("BR123", ref: "ME-7")
    assert pedido.enviado?
    assert_equal "BR123", pedido.rastreamento_codigo
    assert_equal "ME-7", pedido.melhor_envio_ref
    pedido.marcar_entregue!
    assert pedido.entregue?
  end

  test "transição que pula etapas levanta RecordInvalid" do
    assert_raises(ActiveRecord::RecordInvalid) { pedido_pago_envio.marcar_entregue! }
  end

  test "transição é idempotente (não repete)" do
    pedido = pedido_pago_envio
    pedido.marcar_em_producao!
    assert_nothing_raised { pedido.marcar_em_producao! }
  end

  test "pagar um pedido de envio agenda a etiqueta" do
    pedido = Pedido.create!(comprador: users(:ana), tipo_entrega: "envio", endereco: enderecos(:casa_da_ana),
                            status: "aguardando_pagamento", servico_frete: "1", frete_valor: 20, total: 120)
    assert_enqueued_with(job: EtiquetaJob) { pedido.marcar_pago! }
  end

  test "pagar um pedido de retirada NÃO agenda etiqueta" do
    pedido = Checkout.do_carrinho(users(:ana))
    assert_no_enqueued_jobs only: EtiquetaJob do
      pedido.marcar_pago!
    end
  end

  # --- jobs ---

  test "EtiquetaJob compra a etiqueta, grava rastreio e envia (notifica)" do
    pedido = pedido_pago_envio
    perform_enqueued_jobs do
      stub_me(comprar: { ref: "ME-9", codigo: "BR999" }) { EtiquetaJob.perform_now(pedido.id) }
    end
    assert pedido.reload.enviado?
    assert_equal "BR999", pedido.rastreamento_codigo
    assert users(:ana).notifications.joins(:event)
                      .where(noticed_events: { type: "PedidoEnviadoNotifier" }).exists?
  end

  test "RastreioUpdateJob move enviado → entregue quando entregue no ME" do
    pedido = pedido_enviado
    stub_me(rastrear: "delivered") { RastreioUpdateJob.perform_now }
    assert pedido.reload.entregue?
  end

  test "RastreioUpdateJob não mexe enquanto não entregue" do
    pedido = pedido_enviado
    stub_me(rastrear: "posted") { RastreioUpdateJob.perform_now }
    assert pedido.reload.enviado?
  end

  test "EtiquetaJob compra a etiqueta mesmo com o pedido já em produção" do
    pedido = pedido_pago_envio
    pedido.marcar_em_producao!
    stub_me(comprar: { ref: "ME-2", codigo: "BR2" }) { EtiquetaJob.perform_now(pedido.id) }
    assert pedido.reload.enviado?, "gate aceita pago OU em_producao"
  end

  test "EtiquetaJob sem credenciais descarta e o pedido continua pago (sem retry que recompraria)" do
    pedido = pedido_pago_envio # MELHOR_ENVIO_TOKEN vazio → comprar_etiqueta levanta ErroFrete
    assert_nothing_raised { EtiquetaJob.perform_now(pedido.id) } # discard_on engole
    assert pedido.reload.pago?
  end

  test "cancelar! de pedido enviado é bloqueado (não devolve estoque de despachado)" do
    assert_raises(ActiveRecord::RecordInvalid) { pedido_enviado.cancelar! }
  end

  test "chave de cache do frete ignora a máscara do CEP (com e sem hífen batem)" do
    itens = [ item_frete ]
    assert_equal Frete.chave_cache("12010-000", itens), Frete.chave_cache("12010000", itens)
  end

  private

  def item_frete(variante = variantes(:camiseta_m), qtd = 1)
    Struct.new(:variante, :produto, :quantidade).new(variante, variante.produto, qtd)
  end

  def pedido_pago_envio
    Pedido.create!(comprador: users(:ana), tipo_entrega: "envio", endereco: enderecos(:casa_da_ana),
                   status: "pago", servico_frete: "1", frete_valor: 20, total: 120)
  end

  def pedido_enviado
    Pedido.create!(comprador: users(:ana), tipo_entrega: "envio", endereco: enderecos(:casa_da_ana),
                   status: "enviado", servico_frete: "1", frete_valor: 20, total: 120,
                   melhor_envio_ref: "ME-1", rastreamento_codigo: "BR1")
  end

  def stub_requisitar(resposta)
    orig = MelhorEnvio.method(:requisitar)
    MelhorEnvio.define_singleton_method(:requisitar) { |*_| resposta }
    yield
  ensure
    MelhorEnvio.define_singleton_method(:requisitar, orig)
  end

  def stub_me(comprar: nil, rastrear: nil)
    orig = {}
    { comprar_etiqueta: comprar, rastrear: rastrear }.each do |m, v|
      next if v.nil?
      orig[m] = MelhorEnvio.method(m)
      MelhorEnvio.define_singleton_method(m) { |*_| v }
    end
    yield
  ensure
    orig.each { |m, o| MelhorEnvio.define_singleton_method(m, o) }
  end

  def stub_frete(opcoes)
    orig = Frete.method(:cotar)
    Frete.define_singleton_method(:cotar) { |*_| opcoes }
    yield
  ensure
    Frete.define_singleton_method(:cotar, orig)
  end

  def sem_cpf_remetente
    antigo = ENV.delete("MELHOR_ENVIO_CPF_REMETENTE")
    yield
  ensure
    ENV["MELHOR_ENVIO_CPF_REMETENTE"] = antigo if antigo
  end
end
