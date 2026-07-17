# Denunciar um comentário (RF-NOV-09). Cai na aba de denúncias da gestão
# (RF-ADM-05). Throttle em rack_attack.rb.
class DenunciasController < ApplicationController
  before_action :authenticate_user!

  def create
    authorize Denuncia

    comentario = Comentario.find(params[:comentario_id])
    # comentário já moderado não se denuncia de novo: a gestão já tirou do ar,
    # e cada denúncia dessas é uma pendência que nasce sem trabalho a fazer
    unless comentario.visivel?
      return render json: { errors: [ "Este comentário já foi moderado." ] },
                    status: :unprocessable_entity
    end

    denuncia = comentario.denuncias.create!(
      params.expect(denuncia: [ :motivo ]).merge(denunciante: current_user)
    )

    # resposta mínima: a fila da gestão não é do denunciante
    render json: { id: denuncia.id, status: denuncia.status }, status: :created
  end
end
