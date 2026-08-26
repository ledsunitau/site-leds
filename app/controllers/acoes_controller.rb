# Ações (RF-ACO): listagem pública com filtro por tipo, detalhe por tipo
# delegado (Projeto/Evento/Artigo), criação/edição por membros+ (auditada —
# RN-13/RNF-09), destaque da landing e calendário/.ics de eventos.
class AcoesController < ApplicationController
  # Montagem do detalhe delegado e das coleções aninhadas — compartilhada com o
  # painel de gestão (Painel::AcoesController), que escreve as mesmas ações por
  # formulário. Só a resposta difere: JSON aqui, redirect lá.
  include EscritaDeAcao

  before_action :authenticate_user!, only: %i[create update]

  POR_PAGINA = 24 # a grade tem 24 itens antes do pager aparecer
  # Valores aceitos no chip de tipo. Lista fechada: `detalhe_type` vai direto pro
  # where, então qualquer coisa fora daqui é descartada em vez de consultada.
  TIPOS_FILTRO = %w[Projeto Evento Artigo].freeze

  def index
    authorize Acao

    # JSON é o formato PADRÃO (contrato da API — testes e consumidores chamam
    # sem Accept). A página HTML só sai quando o browser pede text/html.
    respond_to do |format|
      format.json do
        acoes = Acao.includes(:detalhe, thumbnail_attachment: :blob).order(created_at: :desc)
        acoes = acoes.where(detalhe_type: filtro(:tipo)) if filtro(:tipo)
        # público vê só publicadas; membros+ podem filtrar por status (rascunhos etc.)
        acoes = if policy(Acao).create? && filtro(:status)
          acoes.where(status: filtro(:status))
        else
          acoes.publicadas
        end
        acoes = acoes.to_a
        preload_temas_dos_artigos(acoes)
        render json: { acoes: acoes.map { |a| acao_json(a) } }
      end

      # Página pública server-rendered. Tipo (chips), busca e página são
      # parâmetros de URL resolvidos AQUI — antes o servidor mandava a tabela
      # inteira e o Stimulus escondia o resto, então buscar só achava o que já
      # estava na tela. ?membro=ID vem do card do membro ("Mais ações") e
      # restringe às ações daquele membro (RF-MEM).
      format.html do
        @membro_filtro = Member.find_by(id: params[:membro])
        base = @membro_filtro ? @membro_filtro.acoes_participadas : Acao.publicadas.order(created_at: :desc)

        @tipo = TIPOS_FILTRO.include?(filtro(:tipo)) ? filtro(:tipo) : nil
        @busca = filtro(:q)
        escopo = base
        escopo = escopo.where(detalhe_type: @tipo) if @tipo
        escopo = buscar_por(escopo, :titulo)

        @pagina = pagina_atual
        @total_paginas = total_de_paginas(escopo, por_pagina: POR_PAGINA)
        @acoes = paginar(escopo.includes(:detalhe, thumbnail_attachment: :blob),
                         por_pagina: POR_PAGINA).to_a
        preload_cards_de_acao(@acoes)

        # Clique em chip/página é requisição de FRAME: renderiza só a lista. Sem
        # isto o servidor montaria navbar, footer e page_bg a cada clique para o
        # Turbo jogar tudo fora menos o frame. O helper também marca o Vary.
        render_em_frame "acoes/lista"
      end
    end
  end

  def show
    acao = Acao.includes(:detalhe, thumbnail_attachment: :blob).find(params[:id])
    authorize acao

    render json: acao_json(acao, completo: true)
  end

  def create
    authorize Acao
    autoriza_arquivamento!(Acao)

    criador = exigir_member!
    return if criador.nil?

    dados = params.require(:acao)
    tipo = TIPOS_DETALHE.keys.find { |k| dados[k].is_a?(ActionController::Parameters) }
    if tipo.nil?
      return render json: { errors: [ "Informe os dados do detalhe em acao[projeto], acao[evento] ou acao[artigo]." ] },
                    status: :unprocessable_entity
    end

    acao = nil
    ActiveRecord::Base.transaction do
      acao = Acao.create!(acao_params.merge(detalhe: montar_detalhe(tipo), criador: criador))
      atualiza_parceiros(acao)
    end

    render json: acao_json(acao, completo: true), status: :created
  end

  def update
    acao = Acao.find(params[:id])
    authorize acao
    autoriza_arquivamento!(acao)

    ActiveRecord::Base.transaction do
      acao.update!(acao_params)
      atualizar_detalhe(acao)
      atualiza_parceiros(acao)
    end

    render json: acao_json(acao, completo: true)
  end

  # RF-INI-02: compilado de ações em destaque para a landing (cache TTL,
  # mesmo esquema do grafo — RNF-01).
  def destaque
    authorize Acao, :index?

    # atenção: do/end aqui se ligaria ao render, não ao fetch (bloco perdido)
    payload = Rails.cache.fetch("acoes/destaque", expires_in: 5.minutes) do
      acoes = Acao.publicadas.order(created_at: :desc).limit(6)
                  .includes(:detalhe, thumbnail_attachment: :blob).to_a
      preload_temas_dos_artigos(acoes)
      { acoes: acoes.map { |a| acao_json(a) } }
    end

    render json: payload
  end

  # RF-ACO-09: eventos publicados num intervalo, para o calendário.
  def calendario
    authorize Acao, :index?

    de = data_do_filtro(:de) || Date.current.beginning_of_month
    ate = data_do_filtro(:ate) || de + 3.months
    ate = [ ate, de + 1.year ].min # janela pública com teto

    eventos = Evento.joins(:acao).merge(Acao.publicadas)
                    .where(data_inicio: de.beginning_of_day..ate.end_of_day)
                    .includes(:acao).order(:data_inicio)
    itens = eventos.map do |evento|
      item = {
        acao_id: evento.acao.id,
        titulo: evento.acao.titulo,
        local: evento.local,
        data_inicio: evento.data_inicio,
        data_fim: evento.data_fim,
        estado: evento.estado
      }
      item[:google_calendar_url] = EventoAgenda.google_url(evento.acao) if evento.estado == "vai_acontecer"
      item
    end

    render json: { eventos: itens }
  end

  # Arquivo .ics do evento (adicionar à agenda — RF-ACO-09).
  def ics
    acao = Acao.find(params[:id])
    authorize acao, :show?
    return head :not_found unless acao.evento?

    render plain: EventoAgenda.ics(acao), content_type: "text/calendar"
  end

  private

  # Foto que foto_de_membro resolve: a do Member, com a do User como fallback
  # (Member#foto_para_card). As duas precisam vir, senão o fallback é que vira o N+1.
  FOTO_DO_MEMBRO = { foto_attachment: :blob, user: { foto_attachment: :blob } }.freeze

  # O que acoes/_card.html.erb toca DENTRO do detalhe, por tipo. O includes(:detalhe)
  # do escopo carrega o detalhe polimórfico, mas nada abaixo dele — daí o N+1.
  CARD_POR_TIPO = {
    "Projeto" => { tecnologias: { icone_attachment: :blob }, membros: FOTO_DO_MEMBRO },
    "Evento" => { membros: FOTO_DO_MEMBRO },
    "Artigo" => { temas: { icone_attachment: :blob }, autores: { member: FOTO_DO_MEMBRO } }
  }.freeze

  # Preload dos cards da PÁGINA (participantes + ícones). Um Preloader por tipo:
  # o detalhe é polimórfico, então não dá para pedir tudo numa associação só.
  #
  # Separado de preload_temas_dos_artigos de propósito: o JSON só toca
  # Artigo#temas (ver os card_json dos models), e carregar membros/fotos lá seria
  # trabalho jogado fora num endpoint que nunca os serializa.
  def preload_cards_de_acao(acoes)
    acoes.group_by(&:detalhe_type).each do |tipo, do_tipo|
      associations = CARD_POR_TIPO[tipo] or next
      detalhes = do_tipo.filter_map(&:detalhe)
      next if detalhes.empty?

      ActiveRecord::Associations::Preloader.new(records: detalhes, associations: associations).call
    end
  end

  # Cards de artigo mostram os ícones dos temas (RF-ACO-05): preload em lote
  # para a listagem não fazer N+1 por artigo. Caminho JSON — o HTML usa
  # preload_cards_de_acao, que é mais largo.
  def preload_temas_dos_artigos(acoes)
    artigos = acoes.select(&:artigo?).map(&:detalhe)
    return if artigos.empty?

    ActiveRecord::Associations::Preloader.new(
      records: artigos, associations: { temas: { icone_attachment: :blob } }
    ).call
  end

  # ---- JSON ----

  def acao_json(acao, completo: false)
    json = {
      id: acao.id,
      tipo: acao.detalhe_type,
      titulo: acao.titulo,
      descricao: acao.descricao,
      status: acao.status,
      thumbnail_url: FotoUrl.para(acao.thumbnail),
      detalhe: detalhe_json(acao, completo: completo)
    }
    if completo
      json[:ideia_id] = acao.ideia_id # idealizador (RF-ACO-07)
      # só ativos: "inativo" tira o parceiro do site público em TODOS os
      # caminhos (vitrine, métrica, perfil e aqui) — senão desativar só o
      # esconde da lista e a marca dele segue publicada em cada ação apoiada
      json[:parceiros] = acao.parceiros.ativos.map(&:card_json) # RF-PAR-02
    end
    json
  end

  # Card por tipo vive nos models (Projeto/Evento/Artigo#card_json); aqui só
  # os campos extras do show, que precisam de params/rotas do controller.
  def detalhe_json(acao, completo:)
    detalhe = acao.detalhe
    json = detalhe&.card_json || {}
    return json unless completo

    case detalhe
    when Projeto
      json[:link] = detalhe.link
      json[:repo_url] = detalhe.repo_url
      json[:hospedagem] = detalhe.hospedagem
      json[:stack] = detalhe.tecnologias.with_attached_icone.map(&:card_json)
      json[:contribuicoes] = detalhe.contribuicoes.includes(member: :user).map do |c|
        { member_id: c.member_id, name: c.member.name, papel: c.papel }
      end
    when Evento
      participacoes = detalhe.evento_membros.includes(member: :user)
      json[:organizadores] = participacoes.select(&:organizador?).map { |em| participante_json(em) }
      json[:participantes] = participacoes.select(&:participante?).map { |em| participante_json(em) }
      # sem id: convidados são recriados a cada edição (replace-all)
      json[:convidados] = detalhe.convidados.includes(:links).map do |c|
        { nome: c.nome, bio: c.bio, links: c.links.map { |l| { rede: l.rede, url: l.url } } }
      end
      json[:google_calendar_url] = EventoAgenda.google_url(acao) if detalhe.estado == "vai_acontecer"
      json[:ics_url] = ics_acao_path(acao)
    when Artigo
      json[:abstract] = detalhe.abstract
      json[:revista] = detalhe.revista
      json[:publicacao_url] = detalhe.publicacao_url
      json[:autores] = detalhe.autores.map do |a|
        { member_id: a.member_id, nome: a.nome, lattes_url: a.lattes_url, ordem: a.ordem }
      end
      json[:apresentacoes] = detalhe.apresentacoes.includes(:congresso).map do |ap|
        { congresso: ap.congresso.nome, ano: ap.ano }
      end
    end

    json
  end

  def participante_json(evento_membro)
    { member_id: evento_membro.member_id, name: evento_membro.member.name }
  end
end
