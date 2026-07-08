# RN-14 / RF-ADM-02: grava o lote de eventos de analytics de uma vez só.
# A própria fila Solid Queue (DB-backed) é o buffer durável — não há buffer
# em cache e não se bate no banco a cada pageview. O controller já verificou
# o consentimento e montou as linhas limpas (chaves string, sem nome vazio);
# aqui só carimbamos created_at e fazemos um insert_all.
class AnalyticsIngestJob < ApplicationJob
  queue_as :default

  def perform(linhas)
    return if linhas.blank?

    agora = Time.current
    AnalyticsEvent.insert_all(linhas.map { |l| l.merge("created_at" => agora) })
  end
end
