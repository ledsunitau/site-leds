# Markdown → HTML do modo markdown do editor de novidades (RF-NOV-04).
#
# O HTML que sai daqui vai para o `corpo` (Action Text) do post, não direto para
# a tela. Isso é de propósito: a página pública, os cards, o JSON, o PaperTrail e
# o anúncio no Discord continuam lendo `corpo` sem saber que existem dois modos.
#
# DUAS camadas de segurança, e as duas importam:
#
#   1. escape_html — HTML cru escrito DENTRO do markdown vira texto visível em
#      vez de markup. Sem isso, "escreva em markdown" seria um campo de HTML
#      livre para qualquer escritor, que é um papel concedido de fora da gestão.
#   2. O sanitizador do Action Text, na renderização. Segunda camada porque a
#      primeira é uma opção de biblioteca: se alguém a afrouxar aqui um dia, o
#      <script> ainda morre na saída.
#
# Tabela precisa de allowed_tags no Action Text (config/initializers/action_text.rb),
# senão o Redcarpet gera a tabela e o sanitizador a remove em silêncio.
#
# O nome NÃO é `Markdown`: o próprio Redcarpet define um ::Markdown global
# (alias de RedcarpetCompat, da era do RDiscount). O Zeitwerk então encontra a
# constante já definida, nunca carrega este arquivo, e `Markdown.para_html`
# estoura um NoMethodError difícil de ler.
module MarkdownRenderer
  extend self

  EXTENSOES = {
    tables: true,              # GFM
    fenced_code_blocks: true,
    autolink: true,
    strikethrough: true,
    # "linha\nlinha" vira duas linhas, como todo editor de texto se comporta.
    # Sem isso o markdown junta as duas num parágrafo só e parece bug pro autor.
    hard_wrap: true,
    # underline/highlight/quote do Redcarpet ficam FORA: geram markup que o
    # sanitizador do Action Text descarta, então acenderiam sintaxe que não
    # aparece na página publicada.
    no_intra_emphasis: true    # nome_de_variavel não vira itálico
  }.freeze

  def para_html(texto)
    return "" if texto.blank?

    renderer.render(texto.to_s)
  end

  private

  # Redcarpet::Markdown NÃO é thread-safe entre renders concorrentes, e o Puma
  # roda multi-thread — por isso um por thread, e não uma constante congelada.
  def renderer
    Thread.current[:markdown_renderer] ||=
      Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(escape_html: true), **EXTENSOES)
  end
end
