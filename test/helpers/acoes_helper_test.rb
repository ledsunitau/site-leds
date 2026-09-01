require "test_helper"

class AcoesHelperTest < ActionView::TestCase
  # data_da_acao chama mes_ano/data_por_extenso, que moram no HomeHelper. Nas
  # views o Rails inclui todos os helpers, mas o TestCase inclui só o do nome.
  include HomeHelper

  # Evento é dia marcado, projeto/artigo é mês de conclusão: a data do card
  # muda de precisão conforme o tipo, e é só isso que estes testes guardam.
  test "evento mostra a data por extenso, com o dia" do
    evento = acoes(:acao_hackathon)
    esperado = format("%02d", evento.detalhe.data_inicio.day)

    assert_match(/\A\d{2} [a-z]{3} \d{4}\z/, data_da_acao(evento))
    assert data_da_acao(evento).start_with?(esperado),
           "a data do evento tem que começar pelo dia de data_inicio"
  end

  test "projeto finalizado mostra só mês e ano" do
    assert_equal "jan 2026", data_da_acao(acoes(:acao_site))
  end

  test "projeto em desenvolvimento não mostra data" do
    assert_equal "em dev", data_da_acao(acoes(:acao_bot))
  end
end
