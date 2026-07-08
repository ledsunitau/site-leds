require "test_helper"

# Cluster 8: consentimento de cookies (RNF-04/05) + coleta de analytics
# só com consentimento (RN-14) + agregações do admin (RF-ADM-02).
class LgpdAnalyticsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "consent registra a escolha, seta cookie anonymous_id e devolve o estado" do
    assert_difference "CookieConsent.count", 1 do
      post consents_path, params: { analytics: "true", marketing: "false" }
    end

    assert_response :created
    body = response.parsed_body
    assert body["analytics"]
    assert_not body["marketing"]
    assert body["anonymous_id"].present?
    assert cookies[:anonymous_id].present?, "cookie assinado foi setado (valor opaco no jar)"

    consent = CookieConsent.last
    assert consent.analytics
    assert_not consent.marketing
    assert_nil consent.user_id, "anônimo: sem usuário"
  end

  test "consent logado grava o usuário e reaproveita cookie existente" do
    sign_in users(:ana)
    post consents_path, params: { analytics: "1", marketing: "1" }

    assert_response :created
    assert_equal users(:ana).id, CookieConsent.last.user_id
  end

  test "coleta SEM consentimento é descartada em silêncio (RN-14)" do
    assert_no_enqueued_jobs do
      post events_path, params: { events: [ { nome: "pageview", rota: "/" } ] }
    end
    assert_response :no_content
  end

  test "coleta COM consentimento enfileira o lote e o worker grava tudo" do
    post consents_path, params: { analytics: "true" }

    assert_enqueued_with(job: AnalyticsIngestJob) do
      post events_path, params: { events: [
        { nome: "pageview", rota: "/", referrer: "google", metadata: { origem: "landing", tags: [ "a", "b" ] } },
        { rota: "/sem-nome" }, # nome em branco: NOT NULL — deve ser descartado
        { nome: "click", rota: "/loja" }
      ] }
    end
    assert_response :accepted

    assert_difference "AnalyticsEvent.count", 2, "linha sem nome não entra" do
      perform_enqueued_jobs
    end

    evento = AnalyticsEvent.find_by(nome: "pageview")
    assert_equal "/", evento.rota
    assert_equal "google", evento.referrer
    # metadata aninhada (array) sobrevive — não é escalar-only
    assert_equal({ "origem" => "landing", "tags" => [ "a", "b" ] }, evento.metadata)
    assert_equal CookieConsent.last.anonymous_id, evento.anonymous_id, "coleta usa o id do consentimento"
    assert evento.ocorrido_em.present?
  end

  test "lote acima do teto é truncado (não deixa insert_all/job crescer sem limite)" do
    post consents_path, params: { analytics: "true" }

    excesso = Array.new(EventsController::LIMITE_LOTE + 5) { { nome: "pageview" } }
    post events_path, params: { events: excesso }

    assert_difference "AnalyticsEvent.count", EventsController::LIMITE_LOTE do
      perform_enqueued_jobs
    end
  end

  test "opt-out depois de opt-in vale: a decisão mais recente manda" do
    post consents_path, params: { analytics: "true" }
    post consents_path, params: { analytics: "false" } # muda de ideia

    assert_no_enqueued_jobs do
      post events_path, params: { events: [ { nome: "pageview" } ] }
    end
  end

  test "admin/metrics fica atrás do gate de gestão" do
    get admin_metrics_path
    assert_response :redirect

    sign_in users(:membro_user)
    get admin_metrics_path
    assert_response :forbidden

    sign_in users(:diretor)
    get admin_metrics_path
    assert_response :success
  end

  test "admin/metrics agrega por nome/rota/dia com janela de período" do
    AnalyticsEvent.insert_all([
      row("pageview", rota: "/", anon: "a", em: 2.days.ago),
      row("pageview", rota: "/loja", anon: "b", em: 1.hour.ago),
      row("click", rota: "/loja", anon: "a", em: 1.hour.ago),
      row("pageview", rota: "/", anon: "a", em: 40.days.ago) # fora da janela
    ])

    sign_in users(:diretor)
    get admin_metrics_path(de: 30.days.ago.to_date.iso8601)

    body = response.parsed_body
    assert_equal 3, body["total"], "o de 40 dias atrás fica fora"
    assert_equal 2, body["visitantes_unicos"], "anon a e b"
    assert_equal 2, body["por_nome"]["pageview"]
    assert_equal 2, body["por_rota"]["/loja"]
  end

  private

  def row(nome, rota:, anon:, em:)
    { nome:, rota:, anonymous_id: anon, ocorrido_em: em, created_at: Time.current }
  end
end
