require "test_helper"

# Os dois modos de editor (RF-NOV-04) e a qualidade da capa.
class PostTest < ActiveSupport::TestCase
  # --- modo markdown ---

  test "markdown é renderizado para o corpo ao salvar" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Com markdown",
                        formato: "markdown",
                        corpo_markdown: "## Subtítulo\n\nTexto com **negrito** e [link](https://leds.dev).")

    html = post.corpo.to_s
    assert_match "<h2>Subtítulo</h2>", html
    assert_match "<strong>negrito</strong>", html
    assert_match %r{<a href="https://leds\.dev">link</a>}, html
  end

  # O <script> não sai daqui como markup em nenhuma das duas camadas: o
  # escape_html do renderizador o transforma em texto, e o sanitizador do Action
  # Text é a segunda barreira. Escritor e jornalista são papéis concedidos de
  # fora da gestão — o campo não pode virar uma porta de HTML livre.
  test "HTML cru dentro do markdown vira texto, não markup" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Com script",
                        formato: "markdown",
                        corpo_markdown: "<script>alert(1)</script>\n\n<img src=x onerror=alert(1)>")

    corpo = post.corpo.to_s
    assert_no_match(/<script/, corpo)
    assert_no_match(/<img/, corpo, "nem como tag nem como veículo do onerror")
    # As duas viram TEXTO: continuam legíveis na página (é o que a pessoa
    # escreveu), só não são mais markup que o navegador executa.
    assert_match "&lt;script&gt;", corpo
    assert_match "&lt;img src=x onerror=alert(1)&gt;", corpo
  end

  # Tabela é o caso que denuncia allowed_tags faltando: o Redcarpet gera a
  # <table> e, sem config/initializers/action_text.rb, o sanitizador a apagava
  # INTEIRA e em silêncio — o autor não via nada e não recebia erro.
  test "tabela em markdown sobrevive ao sanitizador do Action Text" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Com tabela",
                        formato: "markdown",
                        corpo_markdown: "| a | b |\n|---|---|\n| 1 | 2 |")

    assert_match "<table>", post.corpo.to_s
    assert_match "<th>a</th>", post.corpo.to_s
  end

  test "editar o markdown re-renderiza o corpo" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Editável",
                        formato: "markdown", corpo_markdown: "primeira versão")
    post.update!(corpo_markdown: "**segunda** versão")

    assert_match "<strong>segunda</strong>", post.corpo.to_s
    assert_no_match(/primeira/, post.corpo.to_s)
  end

  test "markdown → rico é permitido e o corpo renderizado sobrevive; o fonte some" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Migrando",
                        formato: "markdown", corpo_markdown: "**mantém**")

    post.update!(formato: "rico")

    assert post.rico?
    assert_match "<strong>mantém</strong>", post.corpo.to_s, "o texto não pode sumir na migração"
    assert_nil post.corpo_markdown, "o fonte antigo deixa de valer e não pode ficar para trás"
  end

  test "rico → markdown é recusado: a volta perderia formatação" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Sem volta",
                        formato: "rico", corpo: "<p>escrito no Trix</p>")

    post.formato = "markdown"

    assert_not post.valid?
    assert_match(/não pode voltar para markdown/, post.errors[:formato].to_sentence)
  end

  test "post novo nasce no editor rico" do
    assert_equal "rico", Post.new.formato
  end

  test "formato inválido é 422 da validação, não ArgumentError" do
    post = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "x", formato: "docx")

    assert_not post.valid?
    assert_includes post.errors.attribute_names, :formato
  end

  # RN-02: o corpo em markdown é coluna da tabela posts, então o `changed?` de
  # edicao_de_publicado? já o enxerga — mas isso é fácil de quebrar sem perceber,
  # e o custo seria texto novo no ar sem passar pela gestão.
  test "editar o markdown de post publicado devolve para a fila de aprovação" do
    post = Post.create!(autor: users(:jornalista_user), tipo: "noticia", titulo: "Publicada",
                        formato: "markdown", corpo_markdown: "conteúdo inicial")
    post.submeter!
    post.aprovar!(members(:diretor_cientifica))
    assert post.publicado?

    post.update!(corpo_markdown: "conteúdo NOVO, não aprovado por ninguém")

    assert post.em_aprovacao?, "RN-02: a liberação anterior não vale para o texto novo"
    assert_nil post.approved_at
  end

  # --- capa ---

  test "capa menor que o mínimo é recusada, com a medida na mensagem" do
    post = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "Capa ruim")
    anexar(post, "capa_pequena.png", largura: 400, altura: 300)

    assert_not post.valid?
    assert_match(/1200x630/, post.errors[:thumbnail].to_sentence)
    assert_match(/400x300/, post.errors[:thumbnail].to_sentence, "a mensagem tem que dizer o que a pessoa mandou")
  end

  test "capa grande o suficiente passa" do
    post = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "Capa boa")
    anexar(post, "capa_grande.png", largura: 1600, altura: 900)

    assert post.valid?, post.errors.full_messages.to_sentence
  end

  # A decisão consciente do ImagemValidavel: sem analisador de imagem no
  # servidor (o runner do CI não tem libvips) o metadata vem vazio, e barrar
  # upload por falta de biblioteca seria pior que aceitar uma capa pequena.
  test "dimensão desconhecida não bloqueia o upload" do
    post = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "Sem análise")
    anexar(post, "capa_pequena.png", largura: nil, altura: nil)

    assert post.valid?, post.errors.full_messages.to_sentence
  end

  # O caminho REAL do formulário, sem metadata fixado. Os testes acima medem a
  # regra; este mede o que quase escapou: num upload de formulário o blob só sobe
  # para o service no save, então `blob.analyze` na validação tenta baixar um
  # arquivo que ainda não existe. A validação passava, e a capa pequena entrava
  # no ar em silêncio.
  test "upload de verdade (blob ainda não gravado) é medido, não ignorado" do
    skip "sem libvips neste ambiente" unless libvips?

    ruim = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "Upload pequeno")
    anexar_sem_stub(ruim, "capa_pequena.png")
    assert_not ruim.valid?, "a capa de 400x300 tem que ser recusada no upload de formulário"

    boa = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "Upload grande")
    anexar_sem_stub(boa, "capa_grande.png")
    assert boa.valid?, boa.errors.full_messages.to_sentence
  end

  # A validação lê o io do upload para medi-lo. Se não o rebobinar, o save sobe
  # um arquivo vazio: a validação teria corrompido justamente o upload que aprovou.
  test "medir o upload não consome o arquivo: o blob salvo tem os bytes" do
    skip "sem libvips neste ambiente" unless libvips?

    post = Post.new(autor: users(:membro_user), tipo: "noticia", titulo: "Bytes inteiros")
    anexar_sem_stub(post, "capa_grande.png")
    post.save!

    esperado = File.size(Rails.root.join("test/fixtures/files/capa_grande.png"))
    assert_equal esperado, post.thumbnail.blob.byte_size
    assert_equal esperado, post.thumbnail.blob.download.bytesize
  end

  test "as duas variantes da capa existem, com as medidas que os dois usos pedem" do
    variantes = Post.attachment_reflections["thumbnail"].named_variants

    assert_equal %i[card banner].sort, variantes.keys.sort
    assert_equal [ 720, 480 ], variantes[:card].transformations[:resize_to_limit]
    assert_equal [ 1600, 900 ], variantes[:banner].transformations[:resize_to_limit]
  end

  # O bug que motivou a :banner: a .artigo-banner tem 1180px de largura e recebia
  # a variante do card. Cravar o número aqui porque a regressão é silenciosa —
  # nada quebra, a capa só fica borrada (mesma lição do FotoVariantesTest).
  test ":banner cobre o banner do artigo e :card não cobriria" do
    variantes = Post.attachment_reflections["thumbnail"].named_variants

    assert_operator variantes[:banner].transformations[:resize_to_limit].first, :>=, 1180,
                    ".artigo-banner tem 1180px de largura"
    assert_operator variantes[:card].transformations[:resize_to_limit].first, :<, 1180,
                    ":card é pequena de propósito — por isso o banner não pode usá-la"
  end

  private

  # A suíte roda em ambiente sem libvips (o runner do CI não usa Docker), e lá a
  # validação passa de propósito — ver ImagemValidavel. Os testes do caminho real
  # pulam em vez de falhar por falta de biblioteca.
  def libvips?
    require "vips"
    true
  rescue LoadError
    false
  end

  def anexar_sem_stub(post, arquivo)
    post.thumbnail.attach(
      io: File.open(Rails.root.join("test/fixtures/files", arquivo)),
      filename: arquivo, content_type: "image/png"
    )
  end

  # Fixa o metadata em vez de deixar o Active Storage analisar: assim o teste
  # mede a REGRA (comparar com o mínimo) e não a presença do libvips, que não
  # existe em todo ambiente onde a suíte roda.
  def anexar(post, arquivo, largura:, altura:)
    post.thumbnail.attach(
      io: File.open(Rails.root.join("test/fixtures/files", arquivo)),
      filename: arquivo, content_type: "image/png"
    )
    post.thumbnail.blob.update!(
      metadata: { "width" => largura, "height" => altura, "analyzed" => true }
    )
  end
end
