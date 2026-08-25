# Navegação e rótulos do painel de gestão.
module PainelHelper
  # Sidebar: [[título da seção, [[label, path, chave do badge], ...]], ...].
  # A chave do badge (opcional) aponta para @pendencias, calculado no dashboard
  # e nos controllers que precisam do número na barra.
  def painel_nav
    [
      [ "Visão geral", [
        [ "Dashboard", painel_path, nil ]
      ] ],
      [ "Moderação", [
        [ "Aprovações", painel_aprovacoes_path, :aprovacoes ],
        [ "Denúncias", painel_denuncias_path, :denuncias ],
        [ "Comentários", painel_comentarios_path, nil ],
        [ "Avaliações", painel_avaliacoes_path, nil ]
      ] ],
      [ "Conteúdo", [
        [ "Ações", painel_acoes_path, nil ],
        [ "Novidades", painel_posts_path, nil ],
        [ "Ideias", painel_ideias_path, nil ],
        [ "Catálogos", painel_catalogos_path, nil ]
      ] ],
      [ "Parceiros", [
        [ "Parceiros", painel_parceiros_path, nil ],
        [ "Leads", painel_leads_path, :leads ]
      ] ],
      [ "Loja", [
        [ "Produtos", painel_produtos_path, nil ],
        [ "Categorias", painel_categorias_path, nil ],
        [ "Pedidos", painel_pedidos_path, :pedidos_produzir ],
        [ "Reservas", painel_reservas_path, nil ]
      ] ],
      [ "Pessoas", [
        [ "Membros", painel_membros_path, nil ],
        [ "Usuários e papéis", painel_usuarios_path, nil ],
        [ "Emblemas", painel_emblemas_path, nil ],
        [ "Ranks de emblema", painel_emblema_ranks_path, nil ],
        [ "Elos", painel_elos_path, nil ],
        [ "Estrutura", painel_estrutura_path, nil ]
      ] ],
      [ "Sistema", [
        [ "Recursos", painel_recursos_path, nil ],
        [ "Métricas", painel_metricas_path, nil ],
        [ "Logs de erro", painel_logs_path, :erros_graves_24h ],
        [ "Auditoria", painel_auditoria_path, nil ],
        [ "LGPD", painel_lgpd_path, nil ]
      ] ]
    ]
  end

  # Item ativo: casa pelo início do path, então /painel/produtos/3/edit
  # continua marcando "Produtos". O dashboard exige igualdade — senão ele
  # ficaria ativo em toda tela do painel.
  def painel_ativo?(path)
    return current_page?(path) if path == painel_path

    request.path == path || request.path.start_with?("#{path}/")
  end

  # Contador da sidebar: some quando zero (badge de "0" é ruído).
  def painel_badge(chave)
    valor = (@pendencias || {})[chave].to_i
    return if valor.zero?

    tag.span valor, class: "painel-badge"
  end

  # ---- Auditoria (PaperTrail) ----

  EVENTO_LABEL = { "create" => "criou", "update" => "editou", "destroy" => "removeu" }.freeze

  def evento_label(evento) = EVENTO_LABEL[evento.to_s] || evento.to_s

  # item_type é o nome da classe Ruby; a tela fala português.
  MODELO_LABEL = {
    "Acao" => "Ação", "Projeto" => "Projeto", "Evento" => "Evento", "Artigo" => "Artigo",
    "Post" => "Novidade", "Ideia" => "Ideia", "Comentario" => "Comentário",
    "Denuncia" => "Denúncia", "Produto" => "Produto", "Variante" => "Variante",
    "Categoria" => "Categoria", "Pedido" => "Pedido", "Parceiro" => "Parceiro",
    "ParceriaLead" => "Lead de parceria", "Member" => "Membro", "Mandato" => "Mandato",
    "Diretoria" => "Diretoria", "Gestao" => "Gestão", "Setting" => "Configuração",
    "AcaoParceiro" => "Vínculo com parceiro", "User" => "Usuário",
    "Emblema" => "Emblema", "EmblemaRank" => "Rank de emblema", "Elo" => "Elo"
  }.freeze

  def modelo_label(tipo) = MODELO_LABEL[tipo.to_s] || tipo.to_s

  # ---- Contador dos chips de filtro ----

  # Acima de 99 o número vira "99⁺": o "+" é um sufixo sobrescrito, não um
  # dígito. Assim o contador tem largura previsível e uma liga com 12 mil
  # pedidos não empurra a fila de chips para fora da tela.
  TETO_CONTADOR = 99

  def painel_contador(total)
    total = total.to_i
    conteudo = if total > TETO_CONTADOR
      safe_join([ TETO_CONTADOR.to_s, tag.sup("+") ])
    else
      total.to_s
    end

    tag.span(conteudo, class: "painel-contador")
  end

  # ---- Logs ----

  # Reusa as cores de .painel-badge-status: info/warning/error/fatal não são
  # status de registro, então mapeia para as classes que já existem.
  SEVERIDADE_COR = {
    "info" => "ativo", "warning" => "pendente", "error" => "inativo", "fatal" => "inativo"
  }.freeze

  def severidade_cor(severidade) = SEVERIDADE_COR[severidade.to_s] || ""

  # ---- Datas ----

  # "12 mai 2026, 14:30" — mesmo vocabulário de meses de data_por_extenso.
  def data_e_hora(momento)
    return "—" if momento.blank?

    local = momento.in_time_zone
    "#{local.day} #{HomeHelper::MESES_ABREV[local.month - 1]} #{local.year}, #{local.strftime('%H:%M')}"
  end

  # "há 3 dias" / "há 2 h" — para filas, onde o que importa é a espera.
  def ha_quanto_tempo(momento)
    return "—" if momento.blank?

    "há #{time_ago_in_words(momento)}"
  end
end
