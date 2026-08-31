require "test_helper"

# Modo "cores do próprio SVG" (Emblema#svg_original).
#
# O bug que originou isto: um SVG com gradientes saía como um disco de uma cor
# só. A causa não era o sanitizador — ele preserva `linearGradient`, `viewBox` e
# `url(#id)` intactos — mas o CSS
# `.emblema svg :not([fill="none"]) { fill: currentColor }`, que repinta TODA
# forma com a cor única. As formas ficam todas iguais e a maior cobre as outras.
#
# Como a correção é uma classe CSS, o que dá para travar em teste é: (a) o SVG
# chega inteiro no HTML e (b) a classe de escape aparece só no modo certo.
class EmblemasHelperTest < ActionView::TestCase
  include EmblemasHelper

  SVG_COM_GRADIENTE = <<~SVG.freeze
    <svg viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="c" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#fff3a3"></stop>
          <stop offset="100%" stop-color="#c66a00"></stop>
        </linearGradient>
        <radialGradient id="a">
          <stop offset="0%" stop-color="#ffefa0" stop-opacity=".9"></stop>
        </radialGradient>
      </defs>
      <circle cx="128" cy="128" r="105" fill="url(#a)"></circle>
      <g fill="url(#c)"><path d="m128 10 7 27-7 13-7-13z"></path></g>
    </svg>
  SVG

  def emblema(svg_original:)
    Emblema.new(nome: "Teste", icone_svg: SVG_COM_GRADIENTE, cor: "#00C55B",
                efeito: "nenhum", tipo: "unico", peso: 1, svg_original: svg_original)
  end

  # ---------------------------------------------------------- sanitizador

  test "o sanitizador preserva gradiente, viewBox e a referência url(#id)" do
    saida = emblema_svg(emblema(svg_original: true)).to_s

    # SVG é XML: caso importa. `lineargradient` minúsculo não é elemento de
    # gradiente nenhum, e o fill cairia no vazio.
    assert_includes saida, "linearGradient"
    assert_includes saida, "radialGradient"
    assert_includes saida, "viewBox"
    assert_includes saida, "url(#c)"
    assert_includes saida, "stop-color"
  end

  test "o sanitizador continua removendo script e handler inline" do
    perigoso = Emblema.new(icone_svg: '<svg onload="alert(1)"><script>alert(1)</script>' \
                                      '<circle cx="1" cy="1" r="1"></circle></svg>')
    saida = emblema_svg(perigoso).to_s

    assert_not_includes saida, "script"
    assert_not_includes saida, "onload"
    assert_includes saida, "circle"
  end

  # ------------------------------------------------------ classe de escape

  test "svg_original ligado marca o wrapper com a classe de escape" do
    assert_includes emblema_icone(emblema(svg_original: true)), "svg-original"
  end

  test "svg_original desligado NÃO marca — segue repintando com a cor única" do
    assert_not_includes emblema_icone(emblema(svg_original: false)), "svg-original"
  end

  test "a cor continua no wrapper mesmo no modo original (é o brilho do efeito)" do
    html = emblema_icone(emblema(svg_original: true))
    assert_includes html, "--emblema-cor: #00C55B"
  end

  test "o efeito continua sendo aplicado no modo original" do
    e = emblema(svg_original: true)
    e.efeito = "neon"
    assert_includes emblema_icone(e), "emblema-fx-neon"
  end

  # Elo desenha pelo mesmo CSS e tem a mesma chave de escape.
  def elo(svg_original:, icone_svg: SVG_COM_GRADIENTE)
    Elo.new(nome: "Ferro", cor: "#888888", efeito: "nenhum", pontos_minimos: 0,
            icone_svg: icone_svg, svg_original: svg_original)
  end

  test "elo com svg_original marca o wrapper e mantém a cor para o efeito" do
    html = elo_icone(elo(svg_original: true))
    assert_includes html, "svg-original"
    assert_includes html, "--emblema-cor: #888888"
    assert_includes html, "linearGradient"
  end

  test "elo sem svg_original segue repintado com a cor do degrau" do
    assert_not_includes elo_icone(elo(svg_original: false)), "svg-original"
  end

  # Sem desenho o conteúdo é a inicial do nome — texto, não arte: continua
  # pintado com a cor do elo mesmo com a chave ligada.
  test "elo sem SVG não escapa o repinte da inicial" do
    assert_not_includes elo_icone(elo(svg_original: true, icone_svg: nil)), "svg-original"
  end
end
