# Agregações do painel de gestão (RF-ADM-02). PORO, não ActiveRecord — no
# espírito de MembrosGrafo: consulta e formata, não persiste nada.
#
# Cada método devolve estrutura pronta para a view. As séries saem como
# [[rótulo, valor], ...] — formato que os gráficos SVG (painel/charts/*) comem.
#
# Cache: só os blocos caros e estáveis (KPIs, séries). As PENDÊNCIAS não são
# cacheadas — são o painel de atenção; número velho ali é pior que consulta.
class PainelMetricas
  # Dia local. ocorrido_em/created_at são gravados em UTC (padrão do AR) mas o
  # app opera em America/Sao_Paulo — sem converter, tráfego noturno cai no dia
  # seguinte. Mesmo motivo do Admin::MetricsController.
  #
  # Lista fixa em vez de interpolar o nome da coluna: `Arel.sql` desarma a
  # proteção do AR, então a única garantia real é a expressão nunca vir de fora.
  FUSO = "America/Sao_Paulo".freeze
  TOP = 15 # teto dos rankings: nome/rota vêm de payload público (texto livre)

  # Escritas por extenso, sem interpolação: uma lista de literais que o
  # brakeman consegue provar segura (com interpolação ele acusa SQL injection,
  # e um aviso "que a gente sabe que é falso" é como avisos param de ser lidos).
  DIA_LOCAL = {
    "ocorrido_em" => Arel.sql("DATE((ocorrido_em AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')"),
    "occurred_at" => Arel.sql("DATE((occurred_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')"),
    "consented_at" => Arel.sql("DATE((consented_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')"),
    "pedidos.created_at" => Arel.sql("DATE((pedidos.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')"),
    "users.created_at" => Arel.sql("DATE((users.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')")
  }.freeze

  def self.dia_local(coluna)
    DIA_LOCAL.fetch(coluna)
  end

  def initialize(de: nil, ate: nil)
    @de = de
    @ate = ate
  end

  attr_reader :de, :ate

  # ---------------------------------------------------------------- KPIs

  def kpis
    cache("kpis") do
      acoes = Acao.publicadas.group(:detalhe_type).count
      {
        membros: Member.count,
        projetos: acoes["Projeto"].to_i,
        eventos: acoes["Evento"].to_i,
        artigos: acoes["Artigo"].to_i,
        posts: Post.publicados.count,
        usuarios: User.count,
        parceiros: Parceiro.ativos.count,
        ideias: Ideia.count,
        pedidos_mes: pedidos_do_mes.count,
        receita_mes: pedidos_do_mes.sum(:total),
        produtos: Produto.ativos.count
      }
    end
  end

  # Fila e caixas de entrada. Sem cache de propósito (ver nota da classe).
  def pendencias
    {
      aprovacoes: Post.em_aprovacao.count + Ideia.pendentes.count,
      posts_fila: Post.em_aprovacao.count,
      ideias_fila: Ideia.pendentes.count,
      denuncias: Denuncia.pendentes.count,
      leads: ParceriaLead.where(status: ParceriaLead::ABERTOS).count,
      pedidos_pagar: Pedido.em_aberto.count,
      pedidos_produzir: Pedido.pago.count,
      pedidos_enviar: Pedido.em_producao.count,
      erros_24h: ErrorLog.where(occurred_at: 24.hours.ago..).count,
      erros_graves_24h: ErrorLog.where(occurred_at: 24.hours.ago.., severidade: %w[error fatal]).count,
      jobs_falhados: jobs_falhados
    }
  end

  # ------------------------------------------------------------- Tráfego

  def trafego
    cache("trafego") do
      escopo = periodo(AnalyticsEvent.all, :ocorrido_em)
      {
        total: escopo.count,
        visitantes: escopo.distinct.count(:anonymous_id),
        por_dia: serie(escopo.group(self.class.dia_local("ocorrido_em")).count),
        por_rota: escopo.where.not(rota: nil).group(:rota).order(contagem_desc).limit(TOP).count.to_a,
        por_nome: escopo.group(:nome).order(contagem_desc).limit(TOP).count.to_a,
        por_referrer: escopo.where.not(referrer: [ nil, "" ]).group(:referrer).order(contagem_desc).limit(TOP).count.to_a
      }
    end
  end

  # ------------------------------------------------------------ Conteúdo

  def conteudo
    cache("conteudo") do
      {
        acoes_por_status: Acao.group(:status).count.to_a,
        acoes_por_tipo: Acao.publicadas.group(:detalhe_type).count.to_a,
        posts_por_status: Post.group(:status).count.to_a,
        posts_por_tipo: Post.publicados.group(:tipo).count.to_a,
        posts_por_autor: Post.publicados.joins(:autor).group("users.name").order(contagem_desc).limit(TOP).count.to_a,
        espera_media_horas: espera_media_da_fila,
        ideias_por_status: Ideia.group(:status).count.to_a,
        ideias_por_tipo: Ideia.group(:tipo).count.to_a,
        comentarios_por_status: Comentario.group(:status).count.to_a,
        denuncias_por_status: Denuncia.group(:status).count.to_a
      }
    end
  end

  # ---------------------------------------------------------------- Loja

  def loja
    cache("loja") do
      vendas = periodo(Pedido.where(status: Pedido::PAGOS), :created_at)
      {
        receita: vendas.sum(:total),
        pedidos: vendas.count,
        ticket_medio: vendas.count.zero? ? 0 : (vendas.sum(:total) / vendas.count),
        receita_por_dia: serie(vendas.group(self.class.dia_local("pedidos.created_at")).sum(:total)),
        por_status: Pedido.group(:status).count.to_a,
        funil: funil_da_loja,
        mais_vendidos: mais_vendidos,
        reservas: reservas_por_produto,
        avaliacoes: Avaliacao.group(:nota).count.sort.to_a,
        nota_media: Avaliacao.average(:nota)&.round(2)
      }
    end
  end

  # --------------------------------------------------------- Comunidade

  def comunidade
    cache("comunidade") do
      {
        cadastros_por_dia: serie(periodo(User.all, :created_at).group(self.class.dia_local("users.created_at")).count),
        por_papel: User::ROLES.map { |r| [ r, User.where(role: r).count ] },
        membros_por_diretoria: Mandato.where(gestao: Gestao.vigente).joins(:diretoria)
                                      .group("diretorias.nome").count.to_a,
        membros_por_cargo: Mandato.where(gestao: Gestao.vigente).group(:cargo).count.to_a,
        # opt-OUT: a linha só existe quando alguém desligou o canal
        desligamentos: NotificationPreference.where(enabled: false).group(:canal).count.to_a,
        push: PushSubscription.count,
        discord: OauthIdentity.where(provider: "discord").count
      }
    end
  end

  # ---------------------------------------------------------------- LGPD

  def lgpd
    cache("lgpd") do
      total = CookieConsent.count
      aceitaram = CookieConsent.where(analytics: true).count
      {
        total: total,
        aceitaram: aceitaram,
        taxa: total.zero? ? 0 : (aceitaram * 100.0 / total).round(1),
        por_dia: serie(periodo(CookieConsent.all, :consented_at)
                         .group(self.class.dia_local("consented_at")).count),
        eventos_guardados: AnalyticsEvent.count,
        evento_mais_antigo: AnalyticsEvent.minimum(:ocorrido_em)
      }
    end
  end

  # ----------------------------------------------------------- Erros

  def erros_por_dia
    cache("erros") do
      serie(ErrorLog.where(occurred_at: 30.days.ago..)
                    .group(self.class.dia_local("occurred_at")).count)
    end
  end

  private

  # Cacheia por janela: chaves diferentes para ?de/&ate diferentes, senão a
  # tela filtrada serviria o número da tela sem filtro.
  def cache(nome, &bloco)
    Rails.cache.fetch("painel/#{nome}/#{de}/#{ate}", expires_in: 5.minutes, &bloco)
  end

  def periodo(escopo, coluna)
    escopo = escopo.where(escopo.arel_table[coluna].gteq(de.beginning_of_day)) if de
    escopo = escopo.where(escopo.arel_table[coluna].lteq(ate.end_of_day)) if ate
    escopo
  end

  def contagem_desc = Arel.sql("COUNT(*) DESC")

  def pedidos_do_mes
    Pedido.where(status: Pedido::PAGOS, created_at: Time.zone.now.beginning_of_month..)
  end

  # Série densa: dia sem registro vira zero, senão o gráfico "pula" a lacuna e
  # sugere continuidade que não houve.
  def serie(contagem)
    dados = contagem.transform_keys { |k| k.to_date }
    return [] if dados.empty?

    (dados.keys.min..dados.keys.max).map { |dia| [ dia, dados[dia] || 0 ] }
  end

  # Quanto tempo o que está na fila já esperou (RF-ADM-04). updated_at é quando
  # entrou em em_aprovacao; para ideia, created_at.
  def espera_media_da_fila
    esperas = Post.em_aprovacao.pluck(:updated_at) + Ideia.pendentes.pluck(:created_at)
    return 0 if esperas.empty?

    agora = Time.current
    ((esperas.sum { |t| agora - t } / esperas.size) / 3600).round(1)
  end

  def funil_da_loja
    [
      [ "Itens no carrinho", ItemCarrinho.count ],
      [ "Reservas ativas", Reserva.ativa.count ],
      [ "Pedidos criados", Pedido.count ],
      [ "Pagos", Pedido.where(status: Pedido::PAGOS).count ],
      [ "Entregues", Pedido.entregue.count ]
    ]
  end

  def mais_vendidos
    ItemPedido.joins(:pedido, :produto)
              .where(pedidos: { status: Pedido::PAGOS })
              .group("produtos.nome")
              .order(Arel.sql("SUM(itens_pedido.quantidade) DESC"))
              .limit(TOP)
              .sum(:quantidade)
              .to_a
  end

  # Progresso de cada produto sob demanda rumo à meta que dispara a produção.
  def reservas_por_produto
    ativas = Reserva.ativa.group(:produto_id).sum(:quantidade)
    Produto.sob_demanda.where(id: ativas.keys).map do |produto|
      { produto: produto, reservado: ativas[produto.id].to_i, alvo: produto.quantidade_alvo.to_i }
    end.sort_by { |r| -r[:reservado] }
  end

  # Solid Queue só tem banco próprio em produção (config/database.yml); em
  # dev/test a tabela pode não existir. O guard é table_exists?, NÃO um rescue:
  # uma query que falha aborta a transação inteira do request no Postgres, e o
  # rescue engole a exceção Ruby sem desfazer isso — o próximo SELECT morre com
  # InFailedSqlTransaction. table_exists? consulta o catálogo e nunca falha.
  def jobs_falhados
    return 0 unless SolidQueue::FailedExecution.table_exists?

    SolidQueue::FailedExecution.count
  end
end
