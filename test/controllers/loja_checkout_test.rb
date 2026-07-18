require "test_helper"

# RF-LOJ-04/07/12: checkout, pagamento (webhook do gateway) e disparo de produção.
class LojaCheckoutTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # --- checkout de estoque (RF-LOJ-04) ---

  test "checkout exige login" do
    post checkout_path
    assert_response :redirect
  end

  test "checkout fecha o carrinho num pedido e devolve a URL de pagamento" do
    sign_in users(:ana)

    stub_mp(criar: { id: "pref-1", init_point: "https://mp/pay/1" }) do
      assert_difference "Pedido.count", 1 do
        post checkout_path
      end
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "https://mp/pay/1", body["pagamento_url"]
    assert_equal "aguardando_pagamento", body["pedido"]["status"]
    assert_empty users(:ana).carrinho.reload.itens
  end

  test "checkout com carrinho vazio é 422" do
    sign_in users(:membro_user)
    stub_mp do
      post checkout_path
    end
    assert_response :unprocessable_entity
  end

  test "gateway indisponível: 503, mas o pedido fica (retomável em /pedidos/:id/pagar)" do
    sign_in users(:ana)
    # sem stub e sem credenciais reais → ErroGateway
    ENV["MERCADO_PAGO_ACCESS_TOKEN"], antigo = nil, ENV["MERCADO_PAGO_ACCESS_TOKEN"]
    assert_difference "Pedido.count", 1 do
      post checkout_path
    end
    assert_response :service_unavailable
    assert Pedido.last.aguardando_pagamento?
  ensure
    ENV["MERCADO_PAGO_ACCESS_TOKEN"] = antigo
  end

  # --- webhook do gateway (RF-LOJ-12) ---

  test "webhook aprovado marca o pedido pago e notifica o comprador" do
    sign_in users(:ana)
    pedido = nil
    stub_mp(criar: { id: "p", init_point: "u" }) { post checkout_path }
    pedido = Pedido.last

    perform_enqueued_jobs do
      stub_mp(consultar: { "status" => "approved", "external_reference" => pedido.id.to_s, "transaction_amount" => 99.8 }) do
        post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } }
      end
    end
    assert_response :ok

    assert pedido.reload.pago?
    assert pedido.pagamentos.first.aprovado?
    assert users(:ana).notifications.joins(:event)
                      .where(noticed_events: { type: "PedidoPagoNotifier" }).exists?
  end

  test "webhook recusado não paga o pedido" do
    sign_in users(:ana)
    stub_mp(criar: { id: "p", init_point: "u" }) { post checkout_path }
    pedido = Pedido.last

    stub_mp(consultar: { "status" => "rejected", "external_reference" => pedido.id.to_s, "transaction_amount" => 99.8 }) do
      post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } }
    end
    assert pedido.reload.aguardando_pagamento?
    assert pedido.pagamentos.first.recusado?
  end

  test "webhook duplicado não repaga nem duplica pagamento" do
    sign_in users(:ana)
    stub_mp(criar: { id: "p", init_point: "u" }) { post checkout_path }
    pedido = Pedido.last

    stub_mp(consultar: { "status" => "approved", "external_reference" => pedido.id.to_s, "transaction_amount" => 99.8 }) do
      assert_difference "Pagamento.count", 1 do
        2.times { post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } } }
      end
    end
    assert pedido.reload.pago?
  end

  test "webhook de tipo diferente de payment é ignorado (200)" do
    post pagamentos_webhook_path, params: { type: "merchant_order", data: { id: "1" } }
    assert_response :ok
  end

  test "webhook aprovado com valor MENOR que o total não paga (subpagamento)" do
    sign_in users(:ana)
    stub_mp(criar: { id: "p", init_point: "u" }) { post checkout_path }
    pedido = Pedido.last # total 99.80

    stub_mp(consultar: { "status" => "approved", "external_reference" => pedido.id.to_s, "transaction_amount" => 1.0 }) do
      post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } }
    end
    assert_response :ok
    assert pedido.reload.aguardando_pagamento?, "R$1 não pode quitar um pedido de R$99,80"
  end

  test "webhook para pedido cancelado não dá 500 (sem loop de retry no MP)" do
    sign_in users(:ana)
    stub_mp(criar: { id: "p", init_point: "u" }) { post checkout_path }
    pedido = Pedido.last
    pedido.cancelar! # cliente desistiu; mas o pagamento é aprovado depois

    stub_mp(consultar: { "status" => "approved", "external_reference" => pedido.id.to_s, "transaction_amount" => 99.8 }) do
      post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } }
    end
    assert_response :ok, "estado inconsistente vira 200, não 500"
    assert pedido.reload.cancelado?, "não ressuscita o pedido cancelado"
  end

  # --- assinatura HMAC do webhook (defesa-em-profundidade além do re-fetch) ---

  test "com secret configurado, webhook sem assinatura é 401" do
    com_webhook_secret("s3cr3t") do
      post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } }
    end
    assert_response :unauthorized
  end

  test "com secret configurado, webhook com assinatura HMAC válida processa" do
    sign_in users(:ana)
    stub_mp(criar: { id: "p", init_point: "u" }) { post checkout_path }
    pedido = Pedido.last

    com_webhook_secret("s3cr3t") do
      ts = "123"
      v1 = OpenSSL::HMAC.hexdigest("SHA256", "s3cr3t", "id:999;request-id:req-1;ts:#{ts};")
      perform_enqueued_jobs do
        stub_mp(consultar: { "status" => "approved", "external_reference" => pedido.id.to_s, "transaction_amount" => 99.8 }) do
          post pagamentos_webhook_path, params: { type: "payment", data: { id: "999" } },
               headers: { "HTTP_X_SIGNATURE" => "ts=#{ts},v1=#{v1}", "HTTP_X_REQUEST_ID" => "req-1" }
        end
      end
    end
    assert_response :ok
    assert pedido.reload.pago?
  end

  # --- pedidos do próprio usuário ---

  test "só vejo/pago/cancelo meus pedidos" do
    pedido_alheio = Checkout.do_carrinho(users(:ana))

    # cada request cross-user dá 404 e ERRA; o sign_in do Devise em teste é
    # one-shot e uma request que erra não regrava a sessão — re-sign_in antes de cada.
    sign_in users(:membro_user)
    get pedido_path(pedido_alheio)
    assert_response :not_found

    sign_in users(:membro_user)
    post cancelar_pedido_path(pedido_alheio)
    assert_response :not_found
    assert pedido_alheio.reload.aguardando_pagamento?
  end

  # --- disparo de produção (RF-LOJ-05/07) ---

  test "reservas atingindo a meta disparam a produção e avisam os reservantes" do
    produtos(:moletom).update!(quantidade_alvo: 2)
    # ana já tem ana_moletom (1 reserva ativa); falta 1 para a meta
    assert_enqueued_with(job: DisparoProducaoJob) do
      users(:membro_user).reservas.create!(produto: produtos(:moletom), quantidade: 1)
    end

    perform_enqueued_jobs
    assert users(:ana).notifications.joins(:event)
                      .where(noticed_events: { type: "ProducaoDisparadaNotifier" }).exists?
    assert users(:membro_user).notifications.joins(:event)
                              .where(noticed_events: { type: "ProducaoDisparadaNotifier" }).exists?
  end

  test "reserva abaixo da meta não dispara" do
    produtos(:moletom).update!(quantidade_alvo: 10)
    assert_no_enqueued_jobs only: DisparoProducaoJob do
      users(:membro_user).reservas.create!(produto: produtos(:moletom), quantidade: 1)
    end
  end

  test "disparo conta UNIDADES, não linhas: uma reserva de quantidade = meta dispara" do
    produtos(:moletom).update!(quantidade_alvo: 5) # ana_moletom já soma 1 unidade
    # uma única reserva de 4 leva o total a 5 (== meta). Contando linhas (2) nunca cruzaria.
    assert_enqueued_with(job: DisparoProducaoJob) do
      users(:membro_user).reservas.create!(produto: produtos(:moletom), variante: variantes(:moletom_unico), quantidade: 4)
    end
  end

  test "disparo não re-notifica com o total já acima da meta" do
    produtos(:moletom).update!(quantidade_alvo: 2)
    users(:membro_user).reservas.create!(produto: produtos(:moletom), variante: variantes(:moletom_unico), quantidade: 1) # cruza (total 2)
    assert_no_enqueued_jobs only: DisparoProducaoJob do
      users(:escritor_user).reservas.create!(produto: produtos(:moletom), variante: variantes(:moletom_unico), quantidade: 1)
    end
  end

  test "pagar reserva cria pedido e devolve URL; aprovação converte a reserva" do
    sign_in users(:ana)
    reserva = reservas(:ana_moletom)

    stub_mp(criar: { id: "pr", init_point: "https://mp/pay/r" }) do
      post pagar_reserva_path(reserva)
    end
    assert_response :created
    pedido = reserva.reload.pedido
    assert pedido.present?

    perform_enqueued_jobs do
      stub_mp(consultar: { "status" => "approved", "external_reference" => pedido.id.to_s, "transaction_amount" => 150 }) do
        post pagamentos_webhook_path, params: { type: "payment", data: { id: "111" } }
      end
    end
    assert reserva.reload.convertida?
  end

  private

  # Configura um secret de webhook durante o bloco (restaura no ensure). Sem
  # secret (padrão em teste), a validação de assinatura é pulada.
  def com_webhook_secret(secret)
    antigo = ENV["MERCADO_PAGO_WEBHOOK_SECRET"]
    ENV["MERCADO_PAGO_WEBHOOK_SECRET"] = secret
    yield
  ensure
    ENV["MERCADO_PAGO_WEBHOOK_SECRET"] = antigo
  end

  # Stub do módulo MercadoPago (module_function). Restaura no ensure.
  def stub_mp(criar: nil, consultar: nil)
    orig_criar = MercadoPago.method(:criar_preferencia)
    orig_consultar = MercadoPago.method(:consultar_pagamento)
    MercadoPago.define_singleton_method(:criar_preferencia) { |_pedido| criar } if criar
    MercadoPago.define_singleton_method(:consultar_pagamento) { |_id| consultar } if consultar
    yield
  ensure
    MercadoPago.define_singleton_method(:criar_preferencia, orig_criar)
    MercadoPago.define_singleton_method(:consultar_pagamento, orig_consultar)
  end
end
