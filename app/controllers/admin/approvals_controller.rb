# RF-ADM-04: fila unificada de aprovação — o que está em em_aprovacao,
# mais antigo primeiro. Hoje só posts; ideias entram na F2 (feature/ideias).
class Admin::ApprovalsController < Admin::BaseController
  def index
    posts = Post.em_aprovacao.includes(:autor).order(updated_at: :asc, id: :asc)

    render json: {
      posts: paginar(posts, por_pagina: 50).map do |post|
        {
          id: post.id,
          tipo: post.tipo,
          titulo: post.titulo,
          autor: post.autor && { id: post.autor.id, name: post.autor.name },
          aguardando_desde: post.updated_at
        }
      end
    }
  end
end
