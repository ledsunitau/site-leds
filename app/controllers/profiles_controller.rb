# RF-AUT-06 (parcial): gestão de perfil — nome, foto, contas vinculadas.
# Preferências de notificação chegam na branch feature/notificacoes.
class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: profile_json
  end

  def update
    if current_user.update(profile_params)
      render json: profile_json
    else
      render_invalido(current_user)
    end
  end

  private

  def profile_params
    params.expect(user: [ :name, :foto ])
  end

  def profile_json
    {
      id: current_user.id,
      name: current_user.name,
      email: current_user.email,
      role: current_user.role,
      foto_url: FotoUrl.para(current_user.foto),
      contas_vinculadas: current_user.oauth_identities.map do |identity|
        { id: identity.id, provider: identity.provider, username: identity.username }
      end
    }
  end
end
