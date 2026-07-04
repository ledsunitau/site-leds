class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Google e Discord seguem o mesmo fluxo: logado = vincular; deslogado = entrar/cadastrar.
  def google_oauth2 = handle_auth
  def discord = handle_auth

  def failure
    redirect_to root_path, alert: t("oauth.falha")
  end

  private

  def handle_auth
    auth = request.env["omniauth.auth"]
    provider = OauthIdentity.normalize_provider(auth.provider)

    if user_signed_in?
      link_identity(auth, provider)
    else
      sign_in_with(auth, provider)
    end
  end

  # RF-AUT-05: vincular conta externa ao perfil (uid + @username; nunca tokens).
  def link_identity(auth, provider)
    identity = OauthIdentity.find_or_initialize_by(provider: provider, uid: auth.uid)

    if identity.persisted? && identity.user_id != current_user.id
      redirect_to profile_path, alert: t("oauth.vinculada_a_outra_conta")
    else
      identity.update!(user: current_user, username: auth.info.name)
      redirect_to profile_path, notice: t("oauth.vinculada", provider: provider)
    end
  end

  # RF-AUT-02: login/cadastro via OAuth.
  def sign_in_with(auth, provider)
    identity = OauthIdentity.find_by(provider: provider, uid: auth.uid)
    user = identity&.user || user_for(auth, provider)
    return if user.nil? # user_for já redirecionou

    identity&.update(username: auth.info.name) # mantém o @ atualizado a cada login
    sign_in_and_redirect user, event: :authentication
  end

  # Conta existente com o mesmo e-mail é vinculada; senão cria uma nova.
  def user_for(auth, provider)
    email = auth.info.email
    if email.blank?
      redirect_to new_user_registration_path, alert: t("oauth.sem_email")
      return nil
    end

    user = User.find_by(email: email) || User.create!(
      email: email,
      name: auth.info.name.presence || email.split("@").first,
      password: Devise.friendly_token[0, 20]
    )
    user.oauth_identities.create!(provider: provider, uid: auth.uid, username: auth.info.name)
    user
  end
end
