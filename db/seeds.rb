# Seeds idempotentes (rodar quantas vezes quiser: bin/rails db:seed).
# Tudo numa transação: ou semeia inteiro, ou nada (sem estado pela metade).

ActiveRecord::Base.transaction do
  # --- Dados institucionais (todos os ambientes) ---
  diretorias = [
    "Diretoria de Mídias",
    "Diretoria Científica",
    "Diretoria de Extensão",
    "Tesouraria"
  ].index_with { |nome| Diretoria.find_or_create_by!(nome: nome) }

  # Só cria gestão se não existir NENHUMA (keyed no ano atual, re-rodar em
  # anos seguintes NÃO pode criar uma segunda gestão sobreposta).
  gestao = Gestao.order(:ano_inicio).last ||
           Gestao.create!(ano_inicio: Date.current.year - 1, ano_fim: Date.current.year + 1)

  # Catálogo inicial de tecnologias (stack dos projetos — RF-ACO-03)
  %w[Ruby Rails PostgreSQL JavaScript TypeScript React Python Docker Figma]
    .each { |nome| Tecnologia.find_or_create_by!(nome: nome) }

  # Temas pré-definidos dos artigos (RF-ACO-05, 1 a 3 por artigo)
  [ "Estruturas de Dados", "Inteligência Artificial", "Desenvolvimento Web",
    "Educação", "Otimização", "Segurança" ]
    .each { |nome| Tema.find_or_create_by!(nome: nome) }

  # --- Fundadores placeholder (SÓ dev/test) ---
  # Senha fixa e pública no repo: jamais pode existir em produção; os dados
  # reais entram pela tela de admin (RF-ADM-03).
  if Rails.env.local?
    senha_dev = "leds-mudar-123"

    fundadores = [
      { nome: "Fundadora Presidente", email: "presidente@leds.dev", role: "presidencia",
        cargo: "presidente", diretoria: nil },
      { nome: "Fundador Vice", email: "vice@leds.dev", role: "presidencia",
        cargo: "vice", diretoria: nil },
      { nome: "Fundadora Mídias", email: "midias@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Diretoria de Mídias" },
      { nome: "Fundador Científica", email: "cientifica@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Diretoria Científica" },
      { nome: "Fundadora Extensão", email: "extensao@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Diretoria de Extensão" },
      { nome: "Fundador Tesouraria", email: "tesouraria@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Tesouraria" }
    ]

    fundadores.each do |f|
      user = User.find_or_create_by!(email: f[:email]) do |u|
        u.name = f[:nome]
        u.role = f[:role]
        u.password = senha_dev
      end
      # O bloco acima só roda na CRIAÇÃO. Sem a linha abaixo, um usuário de
      # seed que teve a senha trocada na mão fica inacessível para sempre — e o
      # db:seed deixa de ser o caminho de volta a um ambiente conhecido, que é
      # justamente o que o cabeçalho deste arquivo promete. Estes são fixtures
      # com senha publicada no repo; o estado conhecido é o ponto deles.
      # Guardado por valid_password? para não gastar bcrypt (nem sujar
      # updated_at) quando já está certa.
      user.update!(password: senha_dev) unless user.valid_password?(senha_dev)

      member = Member.find_or_create_by!(user: user) { |m| m.founder = true }

      Mandato.find_or_create_by!(member: member, gestao: gestao) do |m|
        m.cargo = f[:cargo]
        m.diretoria = f[:diretoria] && diretorias[f[:diretoria]]
      end
    end

    # --- Loja: catálogo demo (só dev/test; em produção a gestão cadastra) ---
    cats = [ "Vestuário", "Acessórios", "Papelaria" ]
           .index_with { |nome| Categoria.find_or_create_by!(nome: nome) }
    criador = Member.first # autor do cadastro (auditoria)

    # Foto default = sem anexo → cai no card-placeholder.svg (simula destaque).
    produtos = [
      { nome: "Camiseta LEDS Dev", preco: 69.90, promo: 49.90, cat: "Vestuário",
        destaque: true, desc: "Camiseta oficial da liga, 100% algodão. Confortável pro dia a dia e pras hackathons.",
        tamanhos: { "PP" => 4, "P" => 8, "M" => 10, "G" => 8, "GG" => 5 } },
      { nome: "Moletom LEDS", preco: 149.90, cat: "Vestuário", destaque: true,
        desc: "Moletom pesado com capuz e o triângulo LEDS bordado. Esquenta no frio do campus.",
        tamanhos: { "P" => 3, "M" => 6, "G" => 6, "GG" => 3 } },
      { nome: "Caneca LEDS", preco: 39.90, promo: 29.90, cat: "Acessórios", destaque: true,
        desc: "Caneca de cerâmica 300ml com a logo. Pro café que sustenta o código." },
      { nome: "Adesivos (pack)", preco: 14.90, cat: "Papelaria",
        desc: "Cartela com 6 adesivos das cores node (verde, azul, vermelho, amarelo)." },
      { nome: "Caderno LEDS", preco: 34.90, cat: "Papelaria",
        desc: "Caderno pautado 90g com capa dura. Pra rascunhar estruturas de dados." },
      { nome: "Boné LEDS", preco: 59.90, cat: "Acessórios",
        desc: "Boné aba curva com bordado. Fecho ajustável, tamanho único." }
    ]

    produtos.each do |attrs|
      produto = Produto.find_or_create_by!(nome: attrs[:nome]) do |p|
        p.preco = attrs[:preco]
        p.preco_promocional = attrs[:promo]
        p.descricao = attrs[:desc]
        p.modo_venda = "estoque"
        p.status = "ativo"
        p.destaque = attrs.fetch(:destaque, false)
        p.categoria = cats[attrs[:cat]]
        p.criador = criador
      end

      # Todo produto de estoque precisa de ao menos uma variante (o saldo mora
      # nela). Sem tamanhos definidos, cria uma "Único".
      tamanhos = attrs[:tamanhos] || { "Único" => 20 }
      tamanhos.each do |nome, estoque|
        produto.variantes.find_or_create_by!(nome: nome) { |v| v.estoque = estoque }
      end
    end

    # Galeria demo (dev/test): 5 fotos pra mostrar o "+N" e o lightbox no detalhe.
    # Usa SVGs do repo como stand-in — a gestão sobe as fotos reais depois.
    camiseta = Produto.find_by(nome: "Camiseta LEDS Dev")
    slugs = %w[ruby rails docker python react]
    if camiseta && camiseta.galeria.attachments.size != slugs.size
      camiseta.galeria.purge
      slugs.each do |slug|
        caminho = Rails.root.join("app/assets/images/tech/#{slug}.svg")
        next unless File.exist?(caminho)

        camiseta.galeria.attach(io: File.open(caminho), filename: "#{slug}.svg", content_type: "image/svg+xml")
      end
    end

    # --- Compradores fictícios: pedidos pagos + avaliações (dev/test) ---
    # Pedidos pagos alimentam o "mais vendidos" (soma de quantidade) e habilitam
    # as avaliações (só quem comprou avalia). Camiseta é a campeã de vendas e a
    # única com 5 avaliações (pra ver a paginação de reviews).
    prod = Produto.where(nome: [ "Camiseta LEDS Dev", "Moletom LEDS", "Caneca LEDS",
                                 "Adesivos (pack)", "Caderno LEDS", "Boné LEDS" ]).index_by(&:nome)

    compradores = {
      "Bruno Alves" => { email: "bruno@leds.dev",
        compras: { "Camiseta LEDS Dev" => 3, "Caneca LEDS" => 2, "Boné LEDS" => 1 } },
      "Carla Dias" => { email: "carla@leds.dev",
        compras: { "Camiseta LEDS Dev" => 2, "Moletom LEDS" => 1, "Adesivos (pack)" => 2 } },
      "Diego Souza" => { email: "diego@leds.dev",
        compras: { "Camiseta LEDS Dev" => 4, "Caneca LEDS" => 3, "Caderno LEDS" => 1 } },
      "Elena Rocha" => { email: "elena@leds.dev",
        compras: { "Camiseta LEDS Dev" => 1, "Caneca LEDS" => 2, "Boné LEDS" => 3, "Moletom LEDS" => 2 } },
      "Felipe Lima" => { email: "felipe@leds.dev",
        compras: { "Camiseta LEDS Dev" => 3, "Boné LEDS" => 3, "Moletom LEDS" => 2, "Adesivos (pack)" => 2 } }
    }

    usuarios = {}
    compradores.each do |nome, dados|
      user = User.find_or_create_by!(email: dados[:email]) do |u|
        u.name = nome
        u.password = senha_dev
      end
      user.update!(password: senha_dev) unless user.valid_password?(senha_dev) # ver nota nos fundadores
      usuarios[nome] = user
      next if user.pedidos.any? # idempotente

      # Cria já como pago (sem passar pelo gateway): é só dado de demonstração.
      pedido = Pedido.create!(comprador: user, tipo_entrega: "retirada", status: "pago", total: 0)
      total = dados[:compras].sum do |pnome, qtd|
        produto = prod[pnome] or next 0
        pedido.itens.create!(produto: produto, variante: produto.variantes.first,
                             quantidade: qtd, preco_unitario: produto.preco_atual)
        produto.preco_atual * qtd
      end
      pedido.update!(total: total)
    end

    avaliacoes = [
      [ "Bruno Alves", "Camiseta LEDS Dev", 5, "Camiseta super confortável, o tecido é ótimo e não desbota!" ],
      [ "Carla Dias", "Camiseta LEDS Dev", 4, "Gostei bastante, só achei a modelagem um pouco justa." ],
      [ "Diego Souza", "Camiseta LEDS Dev", 5, "Melhor camiseta de liga que já tive, uso quase todo dia." ],
      [ "Elena Rocha", "Camiseta LEDS Dev", 4, "Boa qualidade e, na promoção, valeu muito a pena." ],
      [ "Felipe Lima", "Camiseta LEDS Dev", 5, "Chegou certinho na retirada e ficou show no corpo." ],
      [ "Diego Souza", "Caneca LEDS", 4, "Caneca linda, segura bem o café e não esquenta a mão." ],
      [ "Bruno Alves", "Caneca LEDS", 5, "Cerâmica de qualidade, virou minha caneca oficial de código." ],
      [ "Elena Rocha", "Boné LEDS", 5, "Boné estiloso e o ajuste é perfeito. Recomendo!" ],
      [ "Felipe Lima", "Boné LEDS", 4, "Bom boné, bordado caprichado. Só queria mais opções de cor." ],
      [ "Felipe Lima", "Moletom LEDS", 5, "Moletom pesado e macio, salva no frio do campus." ],
      [ "Elena Rocha", "Moletom LEDS", 3, "Quentinho, mas veio um pouco maior que o esperado." ]
    ]
    avaliacoes.each do |nome_user, pnome, nota, texto|
      user = usuarios[nome_user]
      produto = prod[pnome]
      next unless user && produto

      Avaliacao.find_or_create_by!(produto: produto, autor: user) do |a|
        a.nota = nota
        a.comentario = texto
      end
    end
  end

  puts "Seeds: #{Diretoria.count} diretorias, gestão #{gestao.ano_inicio}–#{gestao.ano_fim}, " \
       "#{Member.where(founder: true).count} fundadores (fundadores só em dev/test)."
end
