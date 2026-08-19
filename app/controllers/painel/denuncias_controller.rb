# Denúncias de comentário (RF-ADM-05). Resolver é decisão SEPARADA de moderar:
# a gestão pode julgar improcedente (resolve sem ocultar). O contrário é
# automático — Comentario#moderar! já resolve as denúncias daquele comentário.
class Painel::DenunciasController < Painel::BaseController
  POR_PAGINA = 30

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)

    escopo = Denuncia.includes(:denunciante, comentario: %i[autor post]).order(created_at: :asc)
    escopo = @status ? escopo.where(status: @status) : escopo.pendentes
    @denuncias = paginar(escopo, por_pagina: POR_PAGINA)

    # Quantas denúncias cada denunciante já abriu: uma conta denunciando um
    # desafeto em série parece inofensiva quando cada linha é olhada sozinha.
    @por_denunciante = Denuncia.where(user_id: @denuncias.filter_map(&:user_id)).group(:user_id).count
  end

  def resolver
    membro = member_atual
    return if membro.nil?

    Denuncia.find(params[:id]).resolver!(membro)
    voltar_para painel_denuncias_path, "Denúncia resolvida sem moderar o comentário."
  end
end
