# Leitura pública dos membros: cards (RF-MEM), grafo conexo (RF-GRA) e
# geneograma acadêmico (RF-GEN). Endpoints JSON — a renderização (Cytoscape,
# cards) vem com o frontend do Figma. Escrita/gestão fica na branch admin.
class MembersController < ApplicationController
  def index
    authorize Member

    mandatos = mandatos_vigentes
    mandatos = mandatos.where(cargo: filtro(:cargo)) if filtro(:cargo)
    mandatos = mandatos.where(diretoria_id: filtro(:diretoria_id)) if filtro(:diretoria_id)

    render json: { members: mandatos.map { |m| card_json(m.member, m) } }
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

  # Filtros vêm de query string pública: só valores escalares (hash/array em
  # where() levanta TypeError -> 500).
  def filtro(chave)
    valor = params[chave]
    valor if valor.is_a?(String) && valor.present?
  end

  def mandatos_vigentes
    Mandato.where(gestao: gestao_vigente)
           .includes(:diretoria,
                     member: [ { foto_attachment: :blob },
                               { user: [ :oauth_identities, { foto_attachment: :blob } ] } ])
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
      foto_url: FotoUrl.para(member.foto_para_card)
    }
  end
end
