# Trilha de auditoria (RF-ADM-07): quem mudou o quê, com o diff, filtrável por
# modelo, registro, usuário, evento e período.
class Painel::AuditoriaController < Painel::BaseController
  POR_PAGINA = 25

  # Modelos que realmente têm has_paper_trail — o select de filtro sai daqui em
  # vez de um DISTINCT em versions (que varre a tabela inteira só para montar
  # um combo).
  MODELOS = %w[Acao AcaoParceiro Post Ideia Comentario Denuncia Produto Variante
               Categoria Pedido Parceiro Setting].freeze

  def index
    @pendencias = PainelMetricas.new.pendencias
    @item_type = filtro(:item_type)
    @evento = filtro(:evento)
    @pagina = filtro(:pagina).to_i.clamp(1, 100_000)

    # sem a coluna `object` (snapshot completo, nunca lido aqui): o diff é
    # object_changes. Ordena por id — insert-only, id segue created_at.
    escopo = PaperTrail::Version
               .select(:id, :item_type, :item_id, :event, :whodunnit, :created_at, :object_changes)
               .order(id: :desc)
    escopo = escopo.where(item_type: @item_type) if @item_type
    escopo = escopo.where(item_id: filtro(:item_id)) if filtro(:item_id)
    escopo = escopo.where(whodunnit: filtro(:user_id)) if filtro(:user_id)
    escopo = escopo.where(event: @evento) if @evento
    escopo = filtrar_por_periodo(escopo, :created_at)

    # Lê uma linha a mais para saber se há próxima página, em vez de um COUNT(*)
    # na tabela inteira só para desenhar a paginação.
    versoes = escopo.limit(POR_PAGINA + 1).offset((@pagina - 1) * POR_PAGINA).to_a
    @tem_proxima = versoes.size > POR_PAGINA
    versoes = versoes.first(POR_PAGINA)

    autores = User.where(id: versoes.filter_map(&:whodunnit).uniq).index_by { |u| u.id.to_s }

    # o diff é montado AQUI: mudancas_da_versao é protected no
    # ApplicationController (não é helper de view), e a lista de exclusão é
    # compartilhada com posts#versoes — mascarar um atributo sensível um dia
    # tem de valer nos dois lugares.
    @linhas = versoes.map do |versao|
      { versao: versao, autor: autores[versao.whodunnit], mudancas: mudancas_da_versao(versao) }
    end

    @filtros = { item_type: @item_type, evento: @evento, item_id: filtro(:item_id),
                 user_id: filtro(:user_id), de: params[:de], ate: params[:ate] }.compact_blank
  end
end
