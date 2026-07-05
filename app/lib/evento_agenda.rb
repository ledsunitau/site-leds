# Integração de agenda do evento (RF-ACO-09) sem tabela extra:
# URL do Google Calendar e arquivo .ics gerados na hora.
module EventoAgenda
  extend self

  def google_url(acao)
    evento = acao.detalhe
    query = {
      action: "TEMPLATE",
      text: acao.titulo,
      dates: "#{formatar(evento.data_inicio)}/#{formatar(fim_de(evento))}",
      location: evento.local,
      details: acao.descricao
    }.compact_blank

    "https://calendar.google.com/calendar/render?#{query.to_query}"
  end

  def ics(acao)
    evento = acao.detalhe
    linhas = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//LEDS//Sistema LEDS//PT",
      "BEGIN:VEVENT",
      "UID:acao-#{acao.id}@leds",
      "DTSTAMP:#{formatar(Time.current)}",
      "DTSTART:#{formatar(evento.data_inicio)}",
      "DTEND:#{formatar(fim_de(evento))}",
      "SUMMARY:#{escapar(acao.titulo)}",
      evento.local.present? ? "LOCATION:#{escapar(evento.local)}" : nil,
      acao.descricao.present? ? "DESCRIPTION:#{escapar(acao.descricao)}" : nil,
      "END:VEVENT",
      "END:VCALENDAR"
    ].compact

    linhas.map { |l| dobrar(l) }.join("\r\n") + "\r\n"
  end

  private

  # Evento sem data_fim entra na agenda com 1h de duração.
  def fim_de(evento)
    evento.data_fim || evento.data_inicio + 1.hour
  end

  def formatar(tempo)
    tempo.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  # RFC 5545: CR cru é proibido em valores TEXT (normaliza CRLF/CR para \n
  # escapado) e vírgula/;/\ são escapadas.
  def escapar(texto)
    texto.to_s.gsub(/\r\n?/, "\n").gsub(/[\\,;]/) { |c| "\\#{c}" }.gsub("\n", "\\n")
  end

  # RFC 5545 §3.1: linha de conteúdo tem no máximo 75 octetos; continuação
  # começa com espaço. Corta em fronteira de caractere (UTF-8 multibyte).
  def dobrar(linha)
    return linha if linha.bytesize <= 75

    partes = [ +"" ]
    linha.each_char do |char|
      limite = partes.size == 1 ? 75 : 74 # continuações carregam o espaço
      partes << +"" if partes.last.bytesize + char.bytesize > limite
      partes.last << char
    end
    partes.join("\r\n ")
  end
end
