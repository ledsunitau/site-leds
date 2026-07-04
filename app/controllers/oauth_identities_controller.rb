# Desvincular conta externa do perfil (RF-AUT-05).
# Sem trava de "última forma de login": quem ficar sem OAuth sempre pode
# definir senha via recuperação por e-mail (Devise recoverable).
class OauthIdentitiesController < ApplicationController
  before_action :authenticate_user!

  def destroy
    current_user.oauth_identities.find(params[:id]).destroy!
    redirect_to profile_path, notice: t("oauth.desvinculada")
  end
end
