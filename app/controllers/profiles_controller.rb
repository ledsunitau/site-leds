# RF-AUT-06 (parcial): gestão de perfil — nome, foto, contas vinculadas.
# Preferências de notificação chegam na branch feature/notificacoes.
class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    # JSON é o contrato da API (default). A página "Meu perfil" (5 abas) só sai
    # quando o browser pede text/html — mesmo padrão de Ações/Membros/Novidades.
    respond_to do |format|
      format.json { render json: profile_json }
      format.html do
        @user = current_user
        @member = current_user.member
        @acoes = current_user.acoes_creditadas.includes(:detalhe, thumbnail_attachment: :blob)
        @posts = Post.includes(thumbnail_attachment: :blob).where(autor: current_user).order(updated_at: :desc)
        @pedidos = current_user.pedidos.includes(itens: %i[produto variante]).order(created_at: :desc)
        @reservas = current_user.reservas.ativa.includes(:produto, :variante)
        @notificacoes = current_user.notifications.includes(event: :record).newest_first.limit(50)
        @nao_lidas = current_user.notifications.unread.count
      end
    end
  end

  def update
    if current_user.update(profile_params)
      respond_to do |format|
        format.json { render json: profile_json }
        format.html { redirect_to profile_path(anchor: "informacoes"), notice: "Perfil atualizado." }
      end
    else
      respond_to do |format|
        format.json { render_invalido(current_user) }
        format.html { redirect_to profile_path(anchor: "informacoes"), alert: current_user.errors.full_messages.to_sentence }
      end
    end
  end

  private

  def profile_params
    params.expect(user: [ :name, :foto, :bio ])
  end

  def profile_json
    {
      id: current_user.id,
      name: current_user.name,
      email: current_user.email,
      role: current_user.role,
      bio: current_user.bio,
      foto_url: FotoUrl.para(current_user.foto),
      contas_vinculadas: current_user.oauth_identities.map do |identity|
        { id: identity.id, provider: identity.provider, username: identity.username }
      end
    }
  end
end
