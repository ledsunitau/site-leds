require "test_helper"

# Link de resgate com VAGAS. A parte que importa é a corrida: o teto é a
# promessa feita a quem recebeu o link ("os 10 primeiros"), então não pode
# furar sob concorrência.
class EmblemaConviteTest < ActiveSupport::TestCase
  test "reservar_vaga! respeita o teto" do
    convite = emblema_convites(:beta_com_vagas) # usos_max: 2

    assert convite.reservar_vaga!
    assert convite.reservar_vaga!
    assert_not convite.reservar_vaga!, "a terceira não passa"
    assert_equal 2, convite.reload.usos
  end

  test "link sem teto nunca esgota" do
    convite = emblema_convites(:beta_valido) # usos_max: nil

    5.times { assert convite.reservar_vaga! }
    assert_not convite.reload.esgotado?
  end

  test "reservar_vaga! recusa link desligado ou vencido" do
    assert_not emblema_convites(:beta_desligado).reservar_vaga!
    assert_not emblema_convites(:beta_vencido).reservar_vaga!
    assert_equal 0, emblema_convites(:beta_desligado).reload.usos
  end

  # Oito tentativas partindo TODAS do mesmo estado em memória (usos = 0), que é
  # exatamente o que a corrida produz: cada requisição leu a linha antes de
  # qualquer incremento. Com "checa e depois incrementa" as oito passariam; com
  # o UPDATE condicional, o banco deixa só duas entrarem.
  #
  # Não dá para provar paralelismo real aqui: fixtures transacionais fixam UMA
  # conexão para o teste inteiro, então threads serializariam. O que este teste
  # garante é a semântica que torna a corrida segura — o predicado viaja junto
  # com a escrita, em vez de ter sido avaliado antes.
  test "oito tentativas sobre o mesmo estado inicial entregam exatamente 2 vagas" do
    convite = emblema_convites(:beta_com_vagas) # usos_max: 2

    tentativas = 8.times.map { EmblemaConvite.find(convite.id) } # todas com usos = 0
    ganhos = tentativas.map(&:reservar_vaga!)

    assert tentativas.all? { |t| t.usos.zero? }, "todas leram o estado antes de qualquer escrita"
    assert_equal 2, ganhos.count(true)
    assert_equal 2, convite.reload.usos
  end

  test "motivo_da_recusa distingue desligado, vencido e esgotado" do
    assert_match(/desativado/i, emblema_convites(:beta_desligado).motivo_da_recusa)
    assert_match(/expirou/i, emblema_convites(:beta_vencido).motivo_da_recusa)

    esgotado = emblema_convites(:beta_com_vagas)
    2.times { esgotado.reservar_vaga! }
    assert_match(/vagas acabaram/i, esgotado.reload.motivo_da_recusa)

    assert_nil emblema_convites(:beta_valido).motivo_da_recusa
  end

  test "vagas_restantes some quando não há teto" do
    assert_equal 2, emblema_convites(:beta_com_vagas).vagas_restantes
    assert_nil emblema_convites(:beta_valido).vagas_restantes
  end
end
