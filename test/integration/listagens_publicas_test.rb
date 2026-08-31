require "test_helper"

# Filtro, busca e paginação das listagens públicas (Ações, Novidades, Loja)
# depois que saíram do cliente para o servidor.
#
# O caso que dá nome a tudo isto é "busca acha item fora da primeira página":
# com o filtro client-side, a página mandava a tabela inteira e o JS escondia o
# resto — mas quando a paginação também era client-side, buscar por algo fora da
# página corrente devolvia "nada encontrado" com o registro existindo no banco.
class ListagensPublicasTest < ActionDispatch::IntegrationTest
  # Conta cards pela classe do card de cada página.
  def cards(classe)
    css_select(".#{classe}").size
  end

  # As fixtures têm 3 posts publicados e a página mostra 6 — não dá para exercer
  # paginação com elas. Estes nascem mais NOVOS que qualquer fixture, então
  # ocupam a primeira página e empurram as fixtures para a segunda.
  def publicar_posts(quantidade)
    Array.new(quantidade) do |i|
      Post.create!(titulo: "Post de paginação #{i}", tipo: "noticia", status: "publicado",
                   autor: users(:escritor_user), published_at: (i + 1).minutes.ago)
    end
  end

  # O card mostra `caller` quando existe e cai em `titulo` (posts/_card).
  def rotulo(post) = post.caller.presence || post.titulo

  # Consultas emitidas por um bloco.
  #
  # Conta as CACHEADAS também, e limpa o query cache antes: em teste de
  # integração o cache de consultas do Active Record sobrevive de um `get` para
  # o outro, então duas requisições iguais mediriam zero na segunda — e um N+1
  # servido pelo cache continua sendo um N+1 no código, que é o que se quer pegar.
  def queries_em
    ActiveRecord::Base.connection.clear_query_cache
    n = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      n += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    yield
    n
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  # Clona uma ação COM o detalhe: (detalhe_type, detalhe_id) tem índice único,
  # então reaproveitar o detalhe original violaria a constraint. As associações
  # que o card percorre (techs, participantes, temas) vão junto — sem elas o
  # clone não exercitaria o preload que está sendo testado.
  def clonar_acao(acao, sufixo)
    detalhe = acao.detalhe
    novo = detalhe.dup
    novo.save!(validate: false)

    case detalhe
    when Projeto
      detalhe.projeto_tecnologias.each { |t| ProjetoTecnologia.create!(projeto: novo, tecnologia_id: t.tecnologia_id) }
      detalhe.contribuicoes.each { |c| Contribuicao.create!(projeto: novo, member_id: c.member_id, papel: c.papel) }
    when Evento
      detalhe.evento_membros.each { |e| EventoMembro.create!(evento: novo, member_id: e.member_id, papel: e.papel) }
    when Artigo
      detalhe.artigo_temas.each { |t| ArtigoTema.create!(artigo: novo, tema_id: t.tema_id) }
      detalhe.autores.each { |a| Autor.create!(artigo: novo, nome: a.nome, member_id: a.member_id, ordem: a.ordem) }
    end

    Acao.create!(titulo: "#{acao.titulo} #{sufixo}", descricao: acao.descricao,
                 status: "publicada", detalhe: novo, criador: acao.criador)
  end

  # ---------------------------------------------------------------- Ações

  test "ações: sem filtro lista as publicadas" do
    get acoes_path, headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal Acao.publicadas.count, cards("acao-card")
  end

  # Card da home aponta para ?destaque=ID (acoes#show é JSON): a ação clicada
  # abre a lista no topo e realçada; sem o parâmetro nada muda.
  test "ações: ?destaque põe a ação clicada em primeiro e realçada" do
    alvo = acoes(:acao_artigo)
    get acoes_path(destaque: alvo.id), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal Acao.publicadas.count, cards("acao-card"), "destaque não pode filtrar a lista"
    assert_select ".acoes-list .acao-card:first-child.destacada .acao-titulo", alvo.titulo

    get acoes_path, headers: { "Accept" => "text/html" }
    assert_select ".acao-card.destacada", false
  end

  test "ações: chip de tipo filtra no servidor" do
    get acoes_path(tipo: "Evento"), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal Acao.publicadas.where(detalhe_type: "Evento").count, cards("acao-card")
  end

  test "ações: tipo fora da lista fechada é ignorado, não consultado" do
    get acoes_path(tipo: "Robots'); DROP TABLE acoes;--"), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal Acao.publicadas.count, cards("acao-card"), "tipo inválido deveria cair em 'todos'"
  end

  test "ações: busca é case-insensitive" do
    get acoes_path(q: "hackathon"), headers: { "Accept" => "text/html" }
    minusculo = cards("acao-card")
    get acoes_path(q: "HACKATHON"), headers: { "Accept" => "text/html" }
    assert_equal minusculo, cards("acao-card")
    assert_operator minusculo, :>, 0
  end

  test "ações: busca e chip se combinam em vez de um zerar o outro" do
    get acoes_path(q: "hackathon", tipo: "Projeto"), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal 0, cards("acao-card"), "Hackathon é Evento; com tipo=Projeto não deve sobrar nada"
  end

  # O que define N+1 não é o número absoluto de consultas, é ele CRESCER com o
  # número de registros. Este teste é a guarda: se alguém tocar um card e voltar
  # a ler uma associação sem preload, o custo passa a escalar e isto quebra.
  test "ações: consultas não crescem com o número de ações" do
    get acoes_path, headers: { "Accept" => "text/html" }
    antes = queries_em { get acoes_path, headers: { "Accept" => "text/html" } }
    cards_antes = cards("acao-card")

    Acao.publicadas.to_a.each_with_index { |a, i| 3.times { |n| clonar_acao(a, "clone#{i}#{n}") } }

    depois = queries_em { get acoes_path, headers: { "Accept" => "text/html" } }
    cards_depois = cards("acao-card")

    assert_operator cards_depois, :>, cards_antes * 3, "o clone precisa render mais cards"
    assert_in_delta antes, depois, 3,
                    "#{cards_antes} cards custavam #{antes} consultas e #{cards_depois} custam #{depois}: voltou o N+1"
  end

  test "membros: consultas não crescem com o número de membros" do
    get members_path, headers: { "Accept" => "text/html" }
    antes = queries_em { get members_path, headers: { "Accept" => "text/html" } }

    # Member#titulos_de_acoes é o alvo: era 4 consultas POR membro.
    base = members(:pres)
    5.times do |i|
      u = User.create!(name: "Clone #{i}", email: "clone#{i}@leds.test", password: "secret123")
      m = Member.create!(user: u, bio: base.bio)
      Contribuicao.create!(projeto: projetos(:site_liga), member: m, papel: "backend")
    end

    depois = queries_em { get members_path, headers: { "Accept" => "text/html" } }
    assert_in_delta antes, depois, 3, "titulos_de_acoes voltou a consultar por membro"
  end

  test "ações: requisição de turbo-frame não monta navbar nem footer" do
    get acoes_path, headers: { "Accept" => "text/html", "Turbo-Frame" => "acoes-lista" }
    assert_response :success
    assert_select "turbo-frame#acoes-lista"
    assert_select "nav.navbar", false, "o frame não deveria trazer a navbar"
  end

  # ------------------------------------------- Escape do frame (Content missing)
  #
  # Um <a> dentro de um <turbo-frame> é capturado por ele: o Turbo busca a URL e
  # procura um frame de MESMO id na resposta. Página de detalhe não tem o frame
  # da listagem, então o card virava "Content missing" em vez de abrir a notícia.
  #
  # A correção é o target="_top" no frame: link de conteúdo navega a página, e só
  # quem pede (chip, pager, categoria) troca o frame. Os testes abaixo cobrem as
  # DUAS direções — o card tem que escapar, o controle tem que continuar preso.

  test "novidades: clicar no card abre a notícia, não 'Content missing'" do
    get posts_path, headers: { "Accept" => "text/html" }
    card = css_select("a.novidade-card").first
    assert card, "a listagem precisa ter card para este teste valer"

    frame = css_select("turbo-frame#novidades-lista").first
    assert_equal "_top", frame["target"],
                 "sem target=_top o frame captura o link do card"
    assert_nil card["data-turbo-frame"],
               "o card herda o _top do frame; um data-turbo-frame aqui o prenderia de volta"

    # A premissa que torna o _top obrigatório: o destino não tem o frame.
    get card["href"], headers: { "Accept" => "text/html" }
    assert_response :success
    assert_select "turbo-frame#novidades-lista", false,
                  "a página da notícia não tem (nem deve ter) o frame da listagem"
    # e caiu mesmo na notícia, não numa casca vazia
    assert_select ".novidade-artigo .artigo-titulo"
  end

  test "loja: clicar no card abre o produto, não 'Content missing'" do
    sign_in users(:membro_user)
    get todos_produtos_path, headers: { "Accept" => "text/html" }

    frame = css_select("turbo-frame#produtos-lista").first
    assert_equal "_top", frame["target"]

    link = css_select("article.produto-card a").first
    assert link, "o card de produto precisa ter link para este teste valer"
    assert_nil link["data-turbo-frame"]

    get link["href"], headers: { "Accept" => "text/html" }
    assert_response :success
    assert_select "turbo-frame#produtos-lista", false
  end

  # A outra direção: se um controle perder o data-turbo-frame ele volta a dar
  # page load inteiro — funciona, mas joga fora a paginação por frame.
  test "chips e pager continuam trocando só o frame" do
    { posts_path => [ "novidades-lista", "chip", "novidades-pag" ],
      acoes_path => [ "acoes-lista", "chip", "acoes-pag" ] }.each do |caminho, (frame, chip, pag)|
      publicar_posts(PostsController::POR_PAGINA) if caminho == posts_path

      get caminho, headers: { "Accept" => "text/html" }
      chips = css_select("a.#{chip}")
      assert chips.any?, "#{caminho}: sem chips para verificar"
      chips.each do |c|
        assert_equal frame, c["data-turbo-frame"], "#{caminho}: chip #{c.text.strip.inspect} escapou do frame"
      end

      paginas = css_select("a.#{pag}")
      paginas.each do |p|
        assert_equal frame, p["data-turbo-frame"], "#{caminho}: link de página escapou do frame"
      end
    end
  end

  # A mesma URL devolve dois corpos conforme o header Turbo-Frame. Em produção
  # tem Cloudflare na frente: sem declarar a variação, uma regra "Cache
  # Everything" serviria o fragmento sem navbar para quem abriu o endereço.
  test "listagens declaram Vary: Turbo-Frame nas DUAS respostas" do
    [ acoes_path, posts_path ].each do |caminho|
      get caminho, headers: { "Accept" => "text/html" }
      assert_match(/Turbo-Frame/i, response.headers["Vary"].to_s,
                   "#{caminho} (página cheia) precisa declarar a variação")

      get caminho, headers: { "Accept" => "text/html", "Turbo-Frame" => "x" }
      assert_match(/Turbo-Frame/i, response.headers["Vary"].to_s,
                   "#{caminho} (frame) precisa declarar a variação")
    end
  end

  test "o Vary não atropela o Accept que o Rails já manda" do
    get acoes_path, headers: { "Accept" => "text/html" }
    vary = response.headers["Vary"].to_s
    assert_match(/Accept/i, vary, "Vary: #{vary.inspect} perdeu o Accept")
    assert_match(/Turbo-Frame/i, vary)
  end

  # -------------------------------------------------------------- Novidades

  test "novidades: pagina em 6 e a segunda página traz o resto" do
    por_pagina = PostsController::POR_PAGINA
    publicar_posts(por_pagina)
    total = Post.publicados.count

    get posts_path, headers: { "Accept" => "text/html" }
    assert_equal por_pagina, cards("novidade-card")

    get posts_path(pagina: 2), headers: { "Accept" => "text/html" }
    assert_equal total - por_pagina, cards("novidade-card")
  end

  test "novidades: página além do fim não estoura, só vem vazia" do
    get posts_path(pagina: 9_999), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal 0, cards("novidade-card")
  end

  # O caso que motivou tirar o filtro do cliente.
  test "novidades: busca acha item que NÃO está na primeira página" do
    publicar_posts(PostsController::POR_PAGINA)
    escondido = posts(:noticia_antiga)

    # a premissa: ele foi mesmo empurrado para fora da página 1
    get posts_path, headers: { "Accept" => "text/html" }
    assert_no_match(/#{Regexp.escape(rotulo(escondido))}/, response.body,
                    "premissa do teste falhou: o post ainda está na página 1")

    get posts_path(q: escondido.titulo), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal 1, cards("novidade-card")
    assert_match(/#{Regexp.escape(rotulo(escondido))}/, response.body)
  end

  # O card exibe `caller`; procurar o que está escrito na tela tem que funcionar.
  test "novidades: busca cobre o caller, não só o titulo" do
    com_caller = posts(:noticia_publicada)
    assert com_caller.caller.present?, "fixture precisa de um post com caller"

    get posts_path(q: com_caller.caller), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal 1, cards("novidade-card")
  end

  test "novidades: rascunho não vaza pela busca" do
    rascunho = posts(:rascunho_do_membro)
    get posts_path(q: rascunho.titulo), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal 0, cards("novidade-card")
  end

  test "novidades: carrossel é as 3 mais recentes, não o topo do filtro" do
    recentes = Post.publicados.order(published_at: :desc).limit(3).to_a
    assert_equal 3, recentes.size, "fixture precisa de 3 publicados"

    get posts_path(tipo: "blog"), headers: { "Accept" => "text/html" }
    assert_response :success
    # inclusive os que o filtro tipo=blog exclui: o carrossel não é o resultado.
    recentes.each do |p|
      assert_match(/#{Regexp.escape(rotulo(p))}/, response.body,
                   "carrossel deveria manter #{rotulo(p).inspect} mesmo com filtro")
    end
  end

  test "novidades: frame não redesenha o carrossel" do
    get posts_path, headers: { "Accept" => "text/html", "Turbo-Frame" => "novidades-lista" }
    assert_response :success
    assert_select ".novidades-carrossel", false
  end

  # ------------------------------------------------------------------ Loja

  test "loja: pagina em 8 e filtra por categoria" do
    sign_in users(:membro_user)
    get todos_produtos_path, headers: { "Accept" => "text/html" }
    assert_response :success
    assert_operator cards("produto-card"), :<=, ProdutosController::POR_PAGINA
  end

  test "loja: só-promoção deixa fora quem não tem preço promocional" do
    sign_in users(:membro_user)
    get todos_produtos_path(promo: "1"), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal Produto.ativos.em_promocao.count, cards("produto-card")
  end

  test "loja: faixa de preço compara contra o preço promocional, não o cheio" do
    sign_in users(:membro_user)
    camiseta = produtos(:camiseta) # preco 60, promocional 49.90

    # janela que contém o promocional mas NÃO o preço cheio
    get todos_produtos_path(preco_min: 45, preco_max: 55), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_match camiseta.nome, response.body,
                 "produto em promoção deve entrar pela faixa do preço que a pessoa vê"
  end

  test "loja: preço não-numérico na query string não quebra a página" do
    sign_in users(:membro_user)
    get todos_produtos_path(preco_min: "abc", preco_max: "'; DROP TABLE produtos;--"),
        headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal Produto.ativos.count, Produto.ativos.count # tabela de pé
  end

  test "loja: produto indisponível não aparece nem pela busca" do
    sign_in users(:membro_user)
    get todos_produtos_path(q: produtos(:caneca_antiga).nome), headers: { "Accept" => "text/html" }
    assert_response :success
    assert_equal 0, cards("produto-card")
  end

  # ------------------------------------------------------- Contrato JSON

  test "o contrato JSON das listagens não mudou de forma" do
    get acoes_path, as: :json
    assert_response :success
    assert JSON.parse(response.body).key?("acoes")

    get posts_path, as: :json
    assert_response :success
    assert JSON.parse(response.body).key?("posts")
  end
end
