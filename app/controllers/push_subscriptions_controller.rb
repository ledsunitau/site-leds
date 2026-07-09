# Inscrições de Web Push do navegador (RF-NOT-02). O front pega a chave
# pública VAPID, assina no PushManager e manda endpoint + chaves aqui.
# create é upsert por endpoint (reinscrever o mesmo navegador atualiza).
class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    dados = params.expect(push_subscription: %i[endpoint p256dh auth])
    com_upsert_concorrente do
      # endpoint é único GLOBAL: reatribui ao usuário atual (é o navegador dele
      # agora). Escopar em current_user daria 422 e vazaria push para o dono
      # antigo num navegador compartilhado.
      sub = PushSubscription.find_or_initialize_by(endpoint: dados[:endpoint])
      sub.user = current_user
      sub.update!(dados)

      render json: { id: sub.id }, status: :created
    end
  end

  def destroy
    current_user.push_subscriptions.find(params[:id]).destroy!
    head :no_content
  end

  # Chave pública VAPID que o navegador precisa para assinar (é pública).
  def vapid_public_key
    render json: { public_key: ENV["VAPID_PUBLIC_KEY"] }
  end
end
