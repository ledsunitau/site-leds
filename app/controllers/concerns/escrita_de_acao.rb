# Escrita de Ações (RF-ACO): montagem e atualização do detalhe delegado
# (Projeto/Evento/Artigo) e das coleções aninhadas.
#
# Extraído do AcoesController quando o painel de gestão passou a escrever ações
# também. As duas telas divergem só na RESPOSTA (JSON na API, redirect no
# painel); tudo daqui para baixo — o que cada tipo aceita, a semântica de
# coleção (chave ausente = não mexer, [] = esvaziar), a auditoria das junções e
# o mínimo de temas do artigo — precisa valer igual nos dois, senão a API e o
# painel divergem em silêncio.
module EscritaDeAcao
  extend ActiveSupport::Concern

  TIPOS_DETALHE = { "projeto" => Projeto, "evento" => Evento, "artigo" => Artigo }.freeze
  # Uma lista só por tipo: create e update NUNCA podem divergir no que aceitam.
  CAMPOS_DETALHE = {
    "projeto" => %i[link repo_url hospedagem situacao data_finalizacao],
    "evento" => %i[local data_inicio data_fim],
    "artigo" => %i[abstract revista publicacao_url situacao data_finalizacao]
  }.freeze

  private

  def acao_params
    # ideia_id (RF-ACO-07): credita a ideia (idealizador = autor dela) na ação
    # que um MEMBRO constrói. A comunidade propõe mas não constrói ações, então
    # o vínculo não é do autor da ideia — é de quem executa. O model valida que
    # a ideia existe, está aprovada, é imutável após criada e única (uma ação).
    params.require(:acao).permit(:titulo, :descricao, :status, :thumbnail, :ideia_id)
  end

  def detalhe_params(tipo)
    params.require(:acao).permit(tipo => CAMPOS_DETALHE.fetch(tipo)).fetch(tipo, {})
  end

  # RF-PAR-02: parceiros que apoiam a ação. Junção auditada (RNF-09) — o
  # diff-writer registra cada inclusão/remoção no PaperTrail. Vive no nível da
  # AÇÃO (não do detalhe), por isso fora de atualiza_colecoes.
  def atualiza_parceiros(acao)
    substitui_juncao_auditada(acao.acao_parceiros, :parceiro_id, ids_do_payload(:parceiro_ids))
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
      substitui_colecao(detalhe.contribuicoes, contribuicoes_do_payload)
    when Evento
      substitui_colecao(detalhe.evento_membros, lista_do_payload(:evento_membros, :member_id, :papel))
      atualiza_convidados(detalhe)
    when Artigo
      substitui_colecao(detalhe.autores,
                        lista_do_payload(:autores, :member_id, :nome, :lattes_url, :ordem))
      substitui_colecao(detalhe.apresentacoes, lista_do_payload(:apresentacoes, :congresso_id, :ano))
    end
  end

  # Contribuição é (membro, papel), mas quem preenche pensa por PESSOA: a mesma
  # pessoa acumula backend + infra no mesmo projeto. Por isso o painel manda uma
  # linha por membro com `papeis: []`, e a API segue mandando um `papel` por
  # item — as duas formas viram a mesma lista de {member_id, papel}.
  #
  # .uniq porque marcar o mesmo par duas vezes (duas linhas do mesmo membro) é
  # erro de digitação, não pedido de violar o índice único: salvar em silêncio é
  # melhor que devolver 422 e perder o formulário inteiro.
  def contribuicoes_do_payload
    lista = lista_do_payload(:contribuicoes, :member_id, :papel, { papeis: [] })
    return nil if lista.nil?

    lista.flat_map { |item|
      papeis = Array(item[:papeis]).compact_blank.presence || [ item[:papel] ]
      papeis.compact_blank.map { |papel| { member_id: item[:member_id], papel: papel } }
    }.uniq
  end

  # nil = chave ausente no payload (não mexer); [] = esvaziar de propósito.
  def ids_do_payload(chave)
    dados = params.require(:acao).permit(chave => [])
    return nil unless dados.key?(chave)

    dados[chave].compact_blank.map(&:to_i).uniq
  end

  def lista_do_payload(chave, *campos)
    dados = params.require(:acao).permit(chave => campos)
    return nil unless dados.key?(chave)

    # formulário ERB manda hash indexado ("0" => {...}); a API manda array. O
    # resto daqui para baixo espera lista — normaliza aqui, num lugar só.
    itens = dados[chave]
    lista = itens.respond_to?(:values) ? itens.values : itens
    lista.reject { |item| item.to_h.values.all?(&:blank?) }
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
    dados = params.require(:acao).permit(convidados: [ :nome, :bio, :redes_texto, { links: [ :rede, :url ] } ])
    return unless dados.key?(:convidados)

    lista = dados[:convidados]
    lista = lista.values if lista.respond_to?(:values)

    evento.convidados.destroy_all
    lista.each do |c|
      next if c[:nome].blank?

      convidado = evento.convidados.create!(nome: c[:nome], bio: c[:bio])
      links_do_convidado(c).each { |l| convidado.links.create!(l) if l[:url].present? }
    end
  end

  # Duas formas de mandar as redes do convidado, porque os dois clientes têm
  # ergonomias diferentes e nenhum deve se dobrar ao outro:
  #   API    -> links: [{rede:, url:}]  (estruturado)
  #   painel -> redes_texto: "github: https://…\nlinkedin: https://…"
  # Um <input> por link exigiria coleção aninhada dentro de coleção aninhada na
  # tela; uma linha por rede resolve sem essa complexidade.
  def links_do_convidado(convidado)
    if convidado[:redes_texto].present?
      return convidado[:redes_texto].to_s.lines.filter_map do |linha|
        rede, url = linha.split(":", 2)
        next if url.blank?

        { rede: rede.to_s.strip, url: url.to_s.strip }
      end
    end

    links = convidado[:links]
    links = links.values if links.respond_to?(:values)
    links || []
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
end
