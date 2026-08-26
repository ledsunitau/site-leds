require "test_helper"

# O projeto não tem linter de CSS, e application.css é um arquivo só, editado
# por append e por remoção de blocos. Já aconteceu de uma remoção levar o
# SELETOR e deixar as declarações órfãs: o navegador descarta o trecho até
# conseguir se recuperar, então regras seguintes somem sem erro nenhum.
#
# Esta é a checagem mínima que pega isso — não é um parser de CSS.
class ApplicationCssTest < ActiveSupport::TestCase
  CSS = Rails.root.join("app/assets/stylesheets/application.css")

  # comentários podem conter chaves e ponto-e-vírgula soltos
  def sem_comentarios = CSS.read.gsub(%r{/\*.*?\*/}m, "")

  # ...e at-rules de instrução (@import, @charset) terminam em ";" no nível
  # zero por definição — são CSS válido, não declaração órfã.
  #
  # As aspas caem ANTES: a URL do @import das fontes carrega ";" dentro dela
  # (…wght@400;500;600), e sem neutralizar isso o resto da linha pareceria
  # declaração solta. O conteúdo entre aspas não é estrutura de CSS.
  def sem_at_rules
    sem_comentarios.gsub(/'[^']*'|"[^"]*"/, "''").gsub(/@[\w-]+[^;{]*;/, "")
  end

  test "as chaves estão balanceadas" do
    css = sem_comentarios
    assert_equal css.count("{"), css.count("}"),
                 "abre e fecha em números diferentes — há bloco sem fechar ou } sobrando"
  end

  test "não há declaração solta fora de um bloco (bloco órfão de seletor)" do
    profundidade = 0
    linha = 1
    soltas = []

    sem_at_rules.each_char do |c|
      case c
      when "\n" then linha += 1
      when "{" then profundidade += 1
      when "}" then profundidade -= 1
      when ";" then soltas << linha if profundidade.zero?
      end
      # um } a mais já indica desbalanceamento; o outro teste reporta melhor
      break if profundidade.negative?
    end

    assert_empty soltas,
                 "declaração fora de bloco nas linhas #{soltas.first(5).join(', ')} " \
                 "(provável remoção que levou o seletor e deixou o corpo)"
  end

  # As duas devem casar: com background-size S, a posição que fecha o laço é
  # S/(S-1). Em 200% dá 200%. Se alguém mexer num sem mexer no outro, a
  # animação volta a saltar de cor a cada ciclo.
  test "a aritmética do laço do cosmético continua fechando" do
    css = sem_comentarios
    assert_match(/@keyframes cosm-fluxo \{ to \{ background-position: 200% 50%; \} \}/, css)
    assert_match(/\.nome-emblema \{[^}]*background-size: 200% 100%;/m, css)
    assert_no_match(/background-size: 250% 100%/, css,
                    "250% não fecha o laço com posição 200% — ver o cálculo no comentário do CSS")
  end
end
