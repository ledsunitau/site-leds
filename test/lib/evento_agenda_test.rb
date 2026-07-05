require "test_helper"

class EventoAgendaTest < ActiveSupport::TestCase
  test "linhas longas são dobradas em 75 octetos (RFC 5545) sem quebrar UTF-8" do
    descricao = "Programação e estruturas de dados aplicadas à computação — " * 8
    acao = Acao.new(titulo: "Evento Longo", descricao: descricao,
                    detalhe: Evento.new(data_inicio: Time.current))

    corpo = EventoAgenda.ics(acao)

    corpo.split("\r\n").each do |linha|
      assert linha.bytesize <= 75, "linha com #{linha.bytesize} octetos: #{linha[0, 40]}..."
    end
    assert corpo.valid_encoding?
  end

  test "CR/CRLF na descrição vira \\n escapado, nunca CR cru" do
    acao = Acao.new(titulo: "Oficina", descricao: "Traga notebook.\r\nInscrições, no site.",
                    detalhe: Evento.new(data_inicio: Time.current))

    corpo = EventoAgenda.ics(acao)

    assert_includes corpo, "DESCRIPTION:Traga notebook.\\nInscrições\\, no site."
    conteudo_sem_separadores = corpo.gsub("\r\n", "")
    assert_not conteudo_sem_separadores.include?("\r"), "CR cru dentro de valor TEXT"
  end
end
