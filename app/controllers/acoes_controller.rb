# Ações (RF-ACO): listagem pública com filtro por tipo, detalhe por tipo
# delegado (Projeto/Evento/Artigo), criação/edição por membros+ (auditada —
# RN-13/RNF-09), destaque da landing e calendário/.ics de eventos.
class AcoesController < ApplicationController
  before_action :authenticate_user!, only: %i[create update]

  TIPOS_DETALHE = { "projeto" => Projeto, "evento" => Evento, "artigo" => Artigo }.freeze
  # Uma lista só por tipo: create e update NUNCA podem divergir no que aceitam.
  CAMPOS_DETALHE = {
    "projeto" => %i[link repo_url hospedagem situacao data_finalizacao],
    "evento" => %i[local data_inicio data_fim],
    "artigo" => %i[abstract revista publicacao_url situacao data_finalizacao]
  }.freeze

  def index
    authorize Acao

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

  def acao_params
    params.require(:acao).permit(:titulo, :descricao, :status, :thumbnail)
  end

  def detalhe_params(tipo)
    params.require(:acao).permit(tipo => CAMPOS_DETALHE.fetch(tipo)).fetch(tipo, {})
  end

  # ---- montagem/atualização por tipo ----

  def montar_detalhe(tipo)
    detalhe = if tipo == "artigo"
      montar_artigo
    else
      TIPOS_DETALHE.fetch(tipo).create!(detalhe_params(tipo))
    end
    atualiza_colecoes(detalhe)
    detalhe
  end

  def atualizar_detalhe(acao)
    detalhe = acao.detalhe
    tipo = acao.detalhe_type.underscore

    aplica_temas(detalhe) if detalhe.is_a?(Artigo)
    detalhe.update!(detalhe_params(tipo)) if params[:acao]&.key?(tipo)
    atualiza_colecoes(detalhe)
  end

  # Artigo nasce com temas ANTES do save: a validação de 1..3 conta a
  # associação em memória (RN-18).
  def montar_artigo
    artigo = Artigo.new(detalhe_params("artigo"))
    ids = ids_do_payload(:tema_ids)
    atribui_temas_novos(artigo, ids) unless ids.nil?
    artigo.save!
    artigo
  end

  def atualiza_colecoes(detalhe)
    case detalhe
    when Projeto
      substitui_juncao_auditada(detalhe.projeto_tecnologias, :tecnologia_id,
                                ids_do_payload(:tecnologia_ids))
      substitui_colecao(detalhe.contribuicoes, lista_do_payload(:contribuicoes, :member_id, :papel))
    when Evento
      substitui_colecao(detalhe.evento_membros, lista_do_payload(:evento_membros, :member_id, :papel))
      atualiza_convidados(detalhe)
    when Artigo
      substitui_colecao(detalhe.autores,
                        lista_do_payload(:autores, :member_id, :nome, :lattes_url, :ordem))
      substitui_colecao(detalhe.apresentacoes, lista_do_payload(:apresentacoes, :congresso_id, :ano))
    end
  end

  # nil = chave ausente no payload (não mexer); [] = esvaziar de propósito.
  def ids_do_payload(chave)
    dados = params.require(:acao).permit(chave => [])
    return nil unless dados.key?(chave)

    dados[chave].compact_blank.map(&:to_i).uniq
  end

  def lista_do_payload(chave, *campos)
    dados = params.require(:acao).permit(chave => campos)
    dados.key?(chave) ? dados[chave] : nil
  end

  # Coleções são substituídas por inteiro quando enviadas (semântica de
  # editor: o payload é o estado final). destroy_all, NUNCA delete_all:
  # cada remoção precisa virar versão no PaperTrail (RNF-09).
  def substitui_colecao(colecao, itens)
    return if itens.nil?

    colecao.destroy_all
    itens.each { |item| colecao.create!(item) }
  end

  # tecnologia_ids=/tema_ids= removem via delete_all (SEM versões no
  # PaperTrail); aqui o diff é explícito para a auditoria registrar cada
  # remoção/inclusão de junção.
  def substitui_juncao_auditada(juncao, chave_fk, ids)
    return if ids.nil?

    juncao.where.not(chave_fk => ids).destroy_all
    faltantes = ids - juncao.pluck(chave_fk)
    faltantes.each { |id| juncao.create!(chave_fk => id) }
  end

  # Em registro persistido a troca de temas grava NA HORA (e o trigger de
  # máx. 3 dispara no insert) — por isso o guard de contagem vem antes.
  def aplica_temas(artigo)
    ids = ids_do_payload(:tema_ids)
    return if ids.nil?

    unless (1..3).cover?(ids.size)
      artigo.errors.add(:temas, "o artigo precisa de 1 a 3 temas")
      raise ActiveRecord::RecordInvalid.new(artigo)
    end
    substitui_juncao_auditada(artigo.artigo_temas, :tema_id, ids)
  end

  def atribui_temas_novos(artigo, ids)
    artigo.tema_ids = ids
  rescue ActiveRecord::RecordNotFound
    artigo.errors.add(:temas, "contém tema inexistente")
    raise ActiveRecord::RecordInvalid.new(artigo)
  end

  def atualiza_convidados(evento)
    dados = params.require(:acao).permit(convidados: [ :nome, :bio, { links: [ :rede, :url ] } ])
    return unless dados.key?(:convidados)

    evento.convidados.destroy_all
    dados[:convidados].each do |c|
      convidado = evento.convidados.create!(nome: c[:nome], bio: c[:bio])
      (c[:links] || []).each { |l| convidado.links.create!(l) }
    end
  end

  # Entrar OU sair de "arquivada" é gestão (diretoria+), não edição comum —
  # vale para create (nascer arquivada) e update.
  def autoriza_arquivamento!(alvo)
    novo = params.dig(:acao, :status)
    return if novo.blank?

    atual = alvo.is_a?(Acao) ? alvo.status : nil
    return if novo == atual

    authorize(alvo, :arquivar?) if novo == "arquivada" || atual == "arquivada"
  end

  # Cards de artigo mostram os ícones dos temas (RF-ACO-05): preload em lote
  # para a listagem não fazer N+1 por artigo.
  def preload_temas_dos_artigos(acoes)
    artigos = acoes.select(&:artigo?).map(&:detalhe)
    return if artigos.empty?

    ActiveRecord::Associations::Preloader.new(
      records: artigos, associations: { temas: { icone_attachment: :blob } }
    ).call
  end

  # ---- JSON ----

  def acao_json(acao, completo: false)
    {
      id: acao.id,
      tipo: acao.detalhe_type,
      titulo: acao.titulo,
      descricao: acao.descricao,
      status: acao.status,
      thumbnail_url: FotoUrl.para(acao.thumbnail),
      detalhe: detalhe_json(acao, completo: completo)
    }
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
