# Preferências de notificação do usuário (RF-NOT-06). Modelo opt-out: só
# existem linhas para o que o usuário mudou; o resto está ligado por padrão.
# create faz upsert de uma preferência (usuário × canal × categoria).
class NotificationPreferencesController < ApplicationController
  before_action :authenticate_user!

  def index
    prefs = current_user.notification_preferences.order(:categoria, :canal)
    render json: { preferencias: prefs.map { |p| pref_json(p) } }
  end

  def create
    com_upsert_concorrente do
      pref = current_user.notification_preferences
                         .find_or_initialize_by(canal: filtro(:canal), categoria: filtro(:categoria))
      # só um false EXPLÍCITO desliga; ausente/"" (checkbox limpo) volta a true.
      # cast("") é nil e enabled é NOT NULL — sem isso, "" viraria 500, não 422.
      casted = ActiveModel::Type::Boolean.new.cast(params[:enabled])
      pref.enabled = casted.nil? ? true : casted
      pref.save!

      render json: pref_json(pref), status: :created
    end
  end

  private

  def pref_json(pref)
    { id: pref.id, canal: pref.canal, categoria: pref.categoria, enabled: pref.enabled }
  end
end
