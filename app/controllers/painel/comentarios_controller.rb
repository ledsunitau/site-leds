# Moderação de comentários (RF-NOV-10). Listagem global — antes disto a gestão
# só via um comentário quando alguém o denunciava; não havia como varrer o que
# está no ar.
#
# Moderar é escalada só de ida (visivel → oculto → removido): a regra está em
# Comentario#moderar!, que também resolve as denúncias pendentes do comentário.
class Painel::ComentariosController < Painel::BaseController
  POR_PAGINA = 40

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)
    @busca = filtro(:busca)

    escopo = Comentario.includes(:autor, :post, :moderador).order(created_at: :desc)
    escopo = escopo.where(status: @status) if @status
    if @busca
      escopo = escopo.where(Comentario.arel_table[:corpo].matches("%#{Comentario.sanitize_sql_like(@busca)}%"))
    end

    @comentarios = paginar(escopo, por_pagina: POR_PAGINA)
    @contagem = Comentario.group(:status).count
  end

  def moderar
    membro = member_atual
    return if membro.nil?

    comentario = Comentario.find(params[:id])
    comentario.moderar!(params[:status], membro)

    # redirect_back: a aba de denúncias também modera daqui (moderar resolve as
    # denúncias do comentário) — jogar o gestor para a lista geral perderia o
    # lugar dele na fila.
    redirect_back fallback_location: painel_comentarios_path, status: :see_other,
                  notice: "Comentário marcado como #{comentario.status}."
  end
end
