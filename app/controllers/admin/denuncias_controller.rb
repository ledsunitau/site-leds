# RF-ADM-05: aba de denúncias do dashboard, atrás do gate de gestão.
# Resolver a denúncia é decisão separada de moderar o comentário: a gestão pode
# julgar improcedente (resolve sem ocultar). O contrário é automático — moderar
# o comentário resolve as denúncias dele (Comentario#moderar!).
class Admin::DenunciasController < Admin::BaseController
  def index
    escopo = Denuncia.includes(:denunciante, comentario: :autor).order(created_at: :asc)
    escopo = filtro(:status) ? escopo.where(status: filtro(:status)) : escopo.pendentes

    render json: { denuncias: paginar(escopo, por_pagina: 50).map { |d| denuncia_json(d) } }
  end

  def resolver
    denuncia = Denuncia.find(params[:id])

    resolvedor = exigir_member!
    return if resolvedor.nil?

    denuncia.resolver!(resolvedor)
    render json: denuncia_json(denuncia)
  end

  private

  def denuncia_json(denuncia)
    {
      id: denuncia.id,
      motivo: denuncia.motivo,
      status: denuncia.status,
      criada_em: denuncia.created_at,
      # quem denunciou: sem isso a gestão não enxerga uma conta denunciando em
      # série um desafeto — cada item pareceria uma denúncia independente
      denunciante: denuncia.denunciante && { id: denuncia.denunciante.id, name: denuncia.denunciante.name },
      comentario: denuncia.comentario.card_json.merge(post_id: denuncia.comentario.post_id)
    }
  end
end
