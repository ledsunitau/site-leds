# Comentários em posts (RF-NOV-08) e moderação (RF-NOV-10). Leitura pública
# mostra só os visíveis; a gestão vê tudo para operar. Throttle em rack_attack.
class ComentariosController < ApplicationController
  before_action :authenticate_user!, only: %i[create moderar]

  def index
    authorize Comentario
    # quem não pode ver o post não pode ver a discussão dele: sem isto, editar
    # um post publicado (volta para em_aprovacao) tira o artigo do ar mas deixa
    # os comentários expostos — e dá para enumerar rascunhos por /posts/N/comentarios
    authorize post_alvo, :show?

    comentarios = post_alvo.comentarios.includes(:autor).order(created_at: :asc)
    # oculto/removido somem do público; a gestão enxerga para moderar
    comentarios = comentarios.visiveis unless policy(Comentario).moderar?

    render json: { comentarios: paginar(comentarios, por_pagina: 50).map(&:card_json) }
  end

  def create
    authorize Comentario

    # "só post publicado recebe comentário" é validação do model (vale em todo
    # caminho de escrita) — inválido cai no rescue_from RecordInvalid → 422
    comentario = post_alvo.comentarios.create!(
      params.expect(comentario: [ :corpo ]).merge(autor: current_user)
    )
    render json: comentario.card_json, status: :created
  end

  # RF-NOV-10: gestão oculta ou remove (soft delete — a linha fica)
  def moderar
    comentario = Comentario.find(params[:id])
    authorize comentario

    moderador = exigir_member!
    return if moderador.nil?

    comentario.moderar!(filtro(:status), moderador)
    render json: comentario.card_json
  end

  private

  def post_alvo
    @post_alvo ||= Post.find(params[:post_id])
  end
end
