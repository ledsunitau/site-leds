require "test_helper"

class PainelHelperTest < ActionView::TestCase
  # O contador dos chips de filtro tem teto: acima de 99 vira "99⁺", com o "+"
  # sobrescrito em vez de mais dígitos. Sem isso, uma liga com 12 mil pedidos
  # empurraria a fila de chips para fora da tela.
  test "o contador mostra o número exato até 99" do
    assert_equal '<span class="painel-contador">0</span>', painel_contador(0)
    assert_equal '<span class="painel-contador">7</span>', painel_contador(7)
    assert_equal '<span class="painel-contador">99</span>', painel_contador(99)
  end

  test "acima de 99 o contador vira 99 com + sobrescrito" do
    assert_equal '<span class="painel-contador">99<sup>+</sup></span>', painel_contador(100)
    assert_equal '<span class="painel-contador">99<sup>+</sup></span>', painel_contador(99_999)
  end

  test "o contador aceita nil (grupo sem nenhum registro)" do
    assert_equal '<span class="painel-contador">0</span>', painel_contador(nil)
  end

  test "o rótulo do evento de auditoria fala português" do
    assert_equal "criou", evento_label("create")
    assert_equal "editou", evento_label("update")
    assert_equal "removeu", evento_label("destroy")
    # evento desconhecido não vira string vazia: melhor mostrar o cru
    assert_equal "touch", evento_label("touch")
  end

  test "o nome do modelo é traduzido, com o cru como fallback" do
    assert_equal "Novidade", modelo_label("Post")
    assert_equal "Lead de parceria", modelo_label("ParceriaLead")
    assert_equal "ModeloNovo", modelo_label("ModeloNovo")
  end
end
