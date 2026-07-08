require "test_helper"

class AnalyticsIngestJobTest < ActiveJob::TestCase
  test "grava o lote via insert_all carimbando created_at" do
    linhas = [ { "nome" => "pageview", "rota" => "/", "ocorrido_em" => Time.current } ]

    assert_difference "AnalyticsEvent.count", 1 do
      AnalyticsIngestJob.perform_now(linhas)
    end
    assert AnalyticsEvent.last.created_at.present?
  end

  test "lote vazio ou nil não bate no banco" do
    assert_no_difference "AnalyticsEvent.count" do
      AnalyticsIngestJob.perform_now([])
      AnalyticsIngestJob.perform_now(nil)
    end
  end
end
