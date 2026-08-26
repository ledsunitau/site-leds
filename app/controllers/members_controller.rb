# Leitura pública dos membros: cards (RF-MEM), grafo conexo (RF-GRA) e
# geneograma acadêmico (RF-GEN). Endpoints JSON — a renderização (Cytoscape,
# cards) vem com o frontend do Figma. Escrita/gestão fica na branch admin.
class MembersController < ApplicationController
  def index
    authorize Member

    # JSON é o contrato da API (default). A página HTML (cards + grafo +
    # geneograma) só sai quando o browser pede text/html — igual a Ações.
    respond_to do |format|
      format.json do
        mandatos = mandatos_vigentes
        mandatos = mandatos.where(cargo: filtro(:cargo)) if filtro(:cargo)
        mandatos = mandatos.where(diretoria_id: filtro(:diretoria_id)) if filtro(:diretoria_id)
        render json: { members: mandatos.map { |m| card_json(m.member, m) } }
      end

      format.html do
        @grafo = MembrosGrafo.grafo(gestao_vigente)
        @geneograma = MembrosGrafo.geneograma
        @membros = membros_da_pagina # cards: vigentes (por cargo) + ex-membros
        # Em lote: o card lia member.acoes_participadas, que custa 4 consultas
        # por membro. Não paginamos esta tela (os dois grafos precisam de todo
        # mundo de qualquer jeito), então o N+1 era o custo real dela.
        @titulos_de_acoes = Member.titulos_de_acoes(@membros.map { |i| i[:member] })
      end
    end
  end

  def show
    member = Member.includes(:user, foto_attachment: :blob).find(params[:id])
    authorize member

    render json: card_json(member, member.mandatos.find_by(gestao: gestao_vigente))
  end

  # Cacheado com TTL curto (RNF-01): payload barato de recalcular, mas não a
  # cada pageview; edições aparecem em até 5 minutos.
  def grafo
    authorize Member, :index?

    render json: Rails.cache.fetch([ "membros/grafo", gestao_vigente&.id ],
                                   expires_in: 5.minutes) { MembrosGrafo.grafo(gestao_vigente) }
  end

  def geneograma
    authorize Member, :index?

    render json: Rails.cache.fetch("membros/geneograma",
                                   expires_in: 5.minutes) { MembrosGrafo.geneograma }
  end

  private

  def gestao_vigente
    return @gestao_vigente if defined?(@gestao_vigente)

    @gestao_vigente = Gestao.vigente
  end

  def mandatos_vigentes
    Mandato.where(gestao: gestao_vigente)
           .includes(:diretoria,
                     member: [ { foto_attachment: :blob },
                               { tecnologias: { icone_attachment: :blob } },
                               { user: [ :oauth_identities, { foto_attachment: :blob } ] } ])
  end

  # Lista dos cards: membros da gestão vigente (ordenados por cargo) seguidos
  # dos ex-membros (têm mandato, mas nenhum na vigente). Cada item traz o
  # mandato a exibir e se é ex — o filtro por grupo é client-side (Stimulus).
  def membros_da_pagina
    ordem = Mandato::CARGOS.each_with_index.to_h
    vigentes = mandatos_vigentes.to_a.sort_by { |m| [ ordem[m.cargo] || 99, m.member.name ] }
    atuais = vigentes.map(&:member_id)

    ex = Member.where.not(id: atuais).where(id: Mandato.select(:member_id))
               .includes(:user, { tecnologias: { icone_attachment: :blob } },
                         { foto_attachment: :blob }, { mandatos: :diretoria })

    vigentes.map { |m| { member: m.member, mandato: m, ex: false } } +
      ex.map { |mem| { member: mem, mandato: mem.mandatos.max_by(&:gestao_id), ex: true } }
  end

  def card_json(member, mandato)
    {
      id: member.id,
      name: member.name,
      cargo: mandato&.cargo,
      destaque: mandato&.destaque? || false,
      diretoria: mandato&.diretoria&.nome,
      founder: member.founder,
      bio: member.bio,
      discord_username: member.discord_username,
      email: member.email,
      github_url: member.github_url,
      linkedin_url: member.linkedin_url,
      lattes_url: member.lattes_url,
      skills: member.tecnologias.map(&:card_json),
      acoes: member.acoes_participadas.pluck(:titulo),
      foto_url: FotoUrl.para(member.foto_para_card)
    }
  end
end
