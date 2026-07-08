# Coleta de analytics (RN-14). SÓ grava com consentimento; sem ele, o lote é
# descartado em silêncio (não é erro — é a ausência de opt-in). O cliente
# manda um lote já agrupado; aqui só validamos o consentimento, carimbamos a
# hora de ocorrência e enfileiramos — o insert_all real vai no worker
# (AnalyticsIngestJob). A fila DB-backed é o buffer; nada bate no banco por
# pageview. Throttle em rack_attack.rb.
class EventsController < ApplicationController
  # Beacon público sem token CSRF (mesmo motivo do ConsentsController).
  skip_forgery_protection

  # Teto de eventos por request: o throttle conta REQUESTS, não eventos, então
  # sem isto um único POST poderia carregar um lote gigante para o insert_all
  # e inchar o payload do job na fila.
  LIMITE_LOTE = 50

  def create
    anon = anonymous_id
    unless CookieConsent.analytics_permitido?(user: current_user, anonymous_id: anon)
      return head :no_content # RN-14: sem consentimento, não coleta
    end

    agora = Time.current
    linhas = eventos_do_lote.filter_map do |e|
      next if e[:nome].blank? # nome é NOT NULL — insert_all não valida
      {
        "user_id" => current_user&.id,
        "anonymous_id" => anon,
        "nome" => e[:nome],
        "rota" => e[:rota],
        "referrer" => e[:referrer],
        "metadata" => metadata_de(e),
        "ocorrido_em" => agora
      }
    end

    AnalyticsIngestJob.perform_later(linhas) if linhas.any?
    head :accepted
  end

  private

  def eventos_do_lote
    lista = params[:events]
    lista.is_a?(Array) ? lista.first(LIMITE_LOTE) : []
  end

  # metadata é um saco jsonb livre: não vira atributo de model (entra como
  # valor explícito no insert_all), então aceitamos a estrutura inteira que o
  # cliente mandou, inclusive aninhada. permit! porque não há coluna a proteger
  # — um permit(metadata: {}) escalar descartaria arrays/hashes em silêncio.
  def metadata_de(evento)
    meta = evento[:metadata]
    meta.respond_to?(:permit!) ? meta.permit!.to_h : meta
  end
end
