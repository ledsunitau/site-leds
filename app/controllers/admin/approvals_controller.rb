# RF-ADM-04: fila unificada de aprovação — o que aguarda revisão, mais antigo
# primeiro. Posts em em_aprovacao (RN-02) e ideias pendentes (RF-IDE-04).
class Admin::ApprovalsController < Admin::BaseController
  def index
    posts = Post.em_aprovacao.includes(:autor).order(updated_at: :asc, id: :asc)
    ideias = Ideia.pendentes.includes(:autor).order(created_at: :asc, id: :asc)

    # páginas independentes: uma fila mais longa não pode esconder a outra
    render json: {
      posts: paginar(posts, por_pagina: 50, param: :pagina_posts).map do |post|
        {
          id: post.id,
          tipo: post.tipo,
          titulo: post.titulo,
          autor: post.autor && { id: post.autor.id, name: post.autor.name },
          aguardando_desde: post.updated_at
        }
      end,
      ideias: paginar(ideias, por_pagina: 50, param: :pagina_ideias).map do |ideia|
        {
          id: ideia.id,
          tipo: ideia.tipo,
          titulo: ideia.titulo,
          autor: ideia.autor && { id: ideia.autor.id, name: ideia.autor.name },
          aguardando_desde: ideia.created_at
        }
      end
    }
  end
end
