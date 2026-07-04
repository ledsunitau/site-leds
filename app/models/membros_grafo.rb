# Monta os payloads do grafo conexo (RN-06) e do geneograma (RF-GEN).
# Fora do controller de propósito: a landing (RF-INI-06) vai precisar de uma
# variante resumida do MESMO grafo — as regras de aresta ficam num lugar só.
class MembrosGrafo
  # Presidente ao centro; vice, diretores e orientador ligados a ele;
  # membros ligados ao(s) diretor(es) da sua diretoria.
  def self.grafo(gestao)
    mandatos = Mandato.where(gestao: gestao)
                      .includes(member: [ { foto_attachment: :blob },
                                          { user: { foto_attachment: :blob } } ])
                      .to_a
    presidente = mandatos.find(&:presidente?)
    diretores = mandatos.select(&:diretor?).group_by(&:diretoria_id)

    edges = mandatos.flat_map do |m|
      case m.cargo
      when "vice", "diretor", "orientador"
        presidente ? [ { from: m.member_id, to: presidente.member_id } ] : []
      when "membro"
        (diretores[m.diretoria_id] || []).map { |d| { from: m.member_id, to: d.member_id } }
      else
        []
      end
    end

    nodes = mandatos.map do |m|
      { id: m.member_id, name: m.member.name, cargo: m.cargo,
        foto_url: FotoUrl.para(m.member.foto_para_card) }
    end

    { nodes: nodes, edges: edges }
  end

  # Mandatos por gestão (eixo Y = anos), arestas de padrinho e fundadores.
  def self.geneograma
    {
      gestoes: Gestao.order(:ano_inicio)
                     .includes(mandatos: [ :diretoria, { member: :user } ])
                     .map do |g|
        {
          id: g.id,
          ano_inicio: g.ano_inicio,
          ano_fim: g.ano_fim,
          mandatos: g.mandatos.map do |m|
            { member_id: m.member_id, name: m.member.name,
              cargo: m.cargo, diretoria: m.diretoria&.nome }
          end
        }
      end,
      padrinho_edges: Member.where.not(padrinho_id: nil)
                            .pluck(:id, :padrinho_id)
                            .map { |id, padrinho_id| { member_id: id, padrinho_id: padrinho_id } },
      founders: Member.where(founder: true).joins(:user)
                      .pluck(:id, "users.name")
                      .map { |id, name| { member_id: id, name: name } }
    }
  end
end
