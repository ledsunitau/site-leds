# Fila unificada de aprovação (RF-ADM-04): novidades em em_aprovacao (RN-02) e
# ideias pendentes (RF-IDE-04). Mais antigo primeiro — quem espera há mais tempo
# aparece no topo.
#
# As transições são os métodos de model (Post#aprovar!, Ideia#rejeitar!): a
# regra de estado, o lock e a notificação já moram lá.
class Painel::AprovacoesController < Painel::BaseController
  POR_PAGINA = 30

  def index
    @pendencias = PainelMetricas.new.pendencias

    @posts = paginar(
      Post.em_aprovacao.includes(:autor).with_attached_thumbnail.order(updated_at: :asc, id: :asc),
      por_pagina: POR_PAGINA, param: :pagina_posts
    )
    @ideias = paginar(
      Ideia.pendentes.includes(:autor).order(created_at: :asc, id: :asc),
      por_pagina: POR_PAGINA, param: :pagina_ideias
    )
  end

  def aprovar_post
    membro = member_atual
    return if membro.nil?

    post = Post.find(params[:id])
    post.aprovar!(membro)
    voltar_para painel_aprovacoes_path, "“#{post.titulo}” publicada."
  end

  def rejeitar_post
    post = Post.find(params[:id])
    post.rejeitar!
    voltar_para painel_aprovacoes_path, "“#{post.titulo}” rejeitada — o autor foi avisado."
  end

  def aprovar_ideia
    membro = member_atual
    return if membro.nil?

    ideia = Ideia.find(params[:id])
    ideia.aprovar!(membro)
    voltar_para painel_aprovacoes_path, "Ideia “#{ideia.titulo}” aprovada."
  end

  def rejeitar_ideia
    membro = member_atual
    return if membro.nil?

    ideia = Ideia.find(params[:id])
    ideia.rejeitar!(membro)
    voltar_para painel_aprovacoes_path, "Ideia “#{ideia.titulo}” rejeitada."
  end
end
