module HomeHelper
  # Imagem do card (ação/post): usa a thumbnail salva se houver; senão cai na
  # imagem padrão do código (ainda não temos bucket de imagens configurado).
  # Variante :card — Acao e Post declaram a mesma, com as mesmas medidas.
  def card_image_url(record)
    FotoUrl.para(record.thumbnail, :card) || image_path("card-placeholder.svg")
  end

  # Capa em tamanho de HERO (.artigo-banner, 1180x506 CSS). Existe separada da
  # card_image_url porque servir a :card aqui é ampliar uma imagem de 720 em uma
  # caixa de 1180 — o mesmo defeito que a foto de membro tinha antes do b9bf7c7.
  # Só Post declara :banner; card e carrossel continuam na :card.
  def banner_image_url(record)
    FotoUrl.para(record.thumbnail, :banner) || image_path("card-placeholder.svg")
  end

  # O botão "Escrever" de /novidades e do drawer. Deriva da PostPolicy em vez de
  # olhar o papel: escritor escreve blog, jornalista escreve notícia, a liga
  # escreve os dois — e a regra mora numa única casa.
  #
  # policy(Post) (a CLASSE) não serve: pode_escrever? chama record.tipo.
  def pode_escrever_novidade?
    tipos_de_novidade_permitidos.any?
  end

  def tipos_de_novidade_permitidos
    return [] unless user_signed_in?

    Post::TIPOS.select { |t| policy(Post.new(tipo: t)).create? }
  end

  MESES_ABREV = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze

  # "02 ago 2026" — data das novidades (dia mês ano, mês abreviado pt-BR).
  def data_por_extenso(data)
    return "" unless data
    format("%02d %s %d", data.day, MESES_ABREV[data.month - 1], data.year)
  end

  # "mai 2026" — data das ações (mês abreviado pt-BR + ano).
  def mes_ano(data)
    return "" unless data
    "#{MESES_ABREV[data.month - 1]} #{data.year}"
  end

  # Estilo do nó do grafo por cargo (raio, cor do anel, cor do glow).
  CARGO_ESTILO = {
    "presidente" => { r: 22, color: "var(--leds-red)",    glow: "248,74,84" },
    "vice"       => { r: 17, color: "var(--leds-blue)",   glow: "29,132,245" },
    "orientador" => { r: 17, color: "var(--leds-yellow)", glow: "255,238,4" },
    "diretor"    => { r: 15, color: "var(--leds-green)",  glow: "0,197,91" },
    "membro"     => { r: 12, color: "var(--text-subtle)", glow: nil }
  }.freeze

  # Slots fixos do layout em estrela (viewBox 680x470), copiados do Figma:
  # presidente ao centro, vice acima, orientador abaixo, diretores nas quatro
  # diagonais (largas). Os membros penduram do seu diretor, abrindo em leque.
  CENTRO          = [ 340.0, 235.0 ].freeze
  SLOT_VICE       = [ 340.0, 120.0 ].freeze
  SLOT_ORIENTADOR = [ 340.0, 350.0 ].freeze
  SLOTS_DIRETOR   = [ [ 198.0, 168.0 ], [ 482.0, 168.0 ], [ 198.0, 302.0 ], [ 482.0, 302.0 ] ].freeze
  RAIO_MEMBRO     = 240.0 # distância do membro ao centro (para fora do diretor)
  LEQUE_MEMBRO    = 64.0  # abertura entre membros irmãos do mesmo diretor

  # Posiciona o grafo da rede de membros. Entra o payload de MembrosGrafo.grafo
  # (nodes + edges vindos do banco); sai cada nó com x/y/cor/foto e as arestas
  # já em coordenadas. nil se não há nós. A FORMA segue o Figma; o CONTEÚDO
  # (quantos e quem) vem do banco.
  def rede_de_membros(grafo)
    return nil if grafo.nil? || grafo[:nodes].blank?

    cx, cy = CENTRO
    pos = {}
    por_cargo = grafo[:nodes].group_by { |n| n[:cargo] }

    centro = (por_cargo["presidente"] || []).first || grafo[:nodes].first
    pos[centro[:id]] = CENTRO.dup
    if (v = (por_cargo["vice"] || []).first)       then pos[v[:id]] = SLOT_VICE.dup end
    if (o = (por_cargo["orientador"] || []).first) then pos[o[:id]] = SLOT_ORIENTADOR.dup end

    (por_cargo["diretor"] || []).each_with_index do |d, i|
      pos[d[:id]] =
        if (s = SLOTS_DIRETOR[i])
          s.dup
        else # mais de 4 diretores: anel externo (fora do padrão do Figma)
          ang = ((i - SLOTS_DIRETOR.size) * Math::PI / 4) - Math::PI / 2
          [ cx + 150 * Math.cos(ang), cy + 150 * Math.sin(ang) ]
        end
    end

    # membro -> diretor (primeira aresta do grafo). Cada grupo abre em leque
    # na direção radial do diretor, para fora dele.
    alvo = {}
    grafo[:edges].each { |e| alvo[e[:from]] ||= e[:to] }
    (por_cargo["membro"] || []).group_by { |m| alvo[m[:id]] }.each do |dir_id, ms|
      base = pos[dir_id] || CENTRO
      ux = base[0] - cx; uy = base[1] - cy
      norm = Math.hypot(ux, uy); norm = 1.0 if norm.zero?
      ux /= norm; uy /= norm
      px, py = -uy, ux # perpendicular (abre o leque)
      ccx = cx + ux * RAIO_MEMBRO; ccy = cy + uy * RAIO_MEMBRO
      ms.each_with_index do |m, j|
        off = (j - (ms.size - 1) / 2.0) * LEQUE_MEMBRO
        pos[m[:id]] = [ ccx + px * off, ccy + py * off ]
      end
    end

    # defensivo: qualquer nó sem posição vai para um anel externo
    faltantes = grafo[:nodes].reject { |n| pos.key?(n[:id]) }
    faltantes.each_with_index do |n, i|
      ang = (i * 2 * Math::PI / [ faltantes.size, 1 ].max) - Math::PI / 2
      pos[n[:id]] = [ cx + 210 * Math.cos(ang), cy + 210 * Math.sin(ang) ]
    end

    nodes = grafo[:nodes].map do |n|
      est = CARGO_ESTILO[n[:cargo]] || CARGO_ESTILO["membro"]
      x, y = pos[n[:id]]
      { id: n[:id], x: x.round(1), y: y.round(1), r: est[:r], color: est[:color], glow: est[:glow],
        name: n[:name], cargo: n[:cargo], foto_url: n[:foto_url].presence || image_path("avatar-default.svg") }
    end
    edges = grafo[:edges].filter_map do |e|
      a = pos[e[:from]]; b = pos[e[:to]]
      [ a[0].round(1), a[1].round(1), b[0].round(1), b[1].round(1) ] if a && b
    end
    { nodes: nodes, edges: edges }
  end
end
