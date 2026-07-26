module MembersHelper
  # Rótulo do cargo no badge do card.
  CARGO_LABEL = {
    "presidente" => "Presidente", "vice" => "Vice-presidente",
    "diretor" => "Diretor", "orientador" => "Orientador", "membro" => "Membro"
  }.freeze

  def cargo_label(cargo)
    CARGO_LABEL[cargo] || "Membro"
  end

  # Grupo do chip de filtro (client-side). Ex-membro tem prioridade sobre o
  # cargo do último mandato.
  def grupo_do_membro(cargo, ex)
    return "ex-membros" if ex

    case cargo
    when "presidente", "vice" then "presidencia"
    when "diretor"            then "diretores"
    when "orientador"         then "orientador"
    else "membros"
    end
  end

  # Cor do topo do card, por ORDEM de exibição (vermelho, azul, verde;
  # repete) — igual à convenção dos cards de ações/novidades (RF-MEM-05).
  ACENTOS_CARD = [ "var(--leds-red)", "var(--leds-blue)", "var(--leds-green)" ].freeze

  def acento_do_card(indice)
    ACENTOS_CARD[indice % ACENTOS_CARD.size]
  end

  # Genograma (RF-GEN): grafo histórico guiado pelo eixo Y (anos das gestões).
  # X = coluna por diretoria (+ Presidência); Y = ano de início da gestão (mais
  # antigo no topo). Arestas: sucessão (mesma coluna em gestões consecutivas) e
  # linhagem de padrinho. Coordenadas em % (posicionadas via CSS/SVG). nil se
  # não há gestões. Entra o payload de MembrosGrafo.geneograma.
  def genograma_grafo(geneograma)
    gestoes = geneograma[:gestoes].select { |g| g[:mandatos].any? }
    return nil if gestoes.blank?

    diretorias = gestoes.flat_map { |g| g[:mandatos].map { |m| m[:diretoria] } }.compact.uniq.sort
    colunas = [ "Presidência" ] + diretorias
    idx = colunas.each_with_index.to_h
    n = colunas.size

    anos = gestoes.map { |g| g[:ano_inicio] }.uniq.sort
    amin, amax = anos.minmax
    span = amax - amin
    yof = ->(a) { span.zero? ? 50.0 : (6 + (a - amin).to_f / span * 88).round(2) }
    xof = ->(col) { n == 1 ? 50.0 : (8 + idx[col].to_f / (n - 1) * 84).round(2) }

    # nós: presidente + diretores, posicionados por (coluna, ano). Irmãos no
    # mesmo ponto (mesma diretoria/ano) abrem um leque horizontal pequeno.
    brutos = gestoes.flat_map do |g|
      g[:mandatos].filter_map do |m|
        col = m[:cargo] == "presidente" ? "Presidência" : (m[:cargo] == "diretor" ? m[:diretoria] : nil)
        { id: m[:member_id], name: m[:name], cargo: m[:cargo], col: col, ano: g[:ano_inicio] } if col && idx[col]
      end
    end

    nodes = []
    brutos.group_by { |b| [ b[:col], b[:ano] ] }.each do |(col, ano), grupo|
      grupo.each_with_index do |b, j|
        off = (j - (grupo.size - 1) / 2.0) * 5
        nodes << b.merge(x: (xof.call(col) + off).round(2), y: yof.call(ano))
      end
    end

    edges = []
    nodes.group_by { |nd| nd[:col] }.each_value do |col_nodes|
      col_nodes.sort_by { |nd| nd[:ano] }.each_cons(2) do |a, b|
        edges << { x1: a[:x], y1: a[:y], x2: b[:x], y2: b[:y], tipo: "sucessao" }
      end
    end
    por_membro = nodes.group_by { |nd| nd[:id] }
    geneograma[:padrinho_edges].each do |e|
      a = por_membro[e[:member_id]]&.first
      b = por_membro[e[:padrinho_id]]&.first
      edges << { x1: a[:x], y1: a[:y], x2: b[:x], y2: b[:y], tipo: "linhagem" } if a && b
    end

    { anos: anos.map { |a| { ano: a, y: yof.call(a) } }, nodes: nodes, edges: edges }
  end
end
