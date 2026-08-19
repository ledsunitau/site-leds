# LGPD: registro de consentimento de cookies e eliminação de dados de
# comportamento (art. 18).
#
# Faltavam os dois: cookie_consents não era lido em lugar nenhum do admin, e as
# linhas de analytics_events não tinham NENHUM caminho de exclusão — atender um
# pedido de eliminação exigia console de produção. O precedente já existia no
# destroy do lead de parceria.
class Painel::LgpdController < Painel::BaseController
  POR_PAGINA = 50

  def index
    @pendencias = PainelMetricas.new.pendencias
    @lgpd = PainelMetricas.new.lgpd
    @consents = CookieConsent.includes(:user).order(id: :desc).limit(POR_PAGINA)
  end

  # Apaga os eventos de comportamento de um titular. Aceita a conta (user_id) ou
  # o id anônimo do cookie — quem nunca logou só existe pelo segundo.
  def eliminar
    user_id = params[:user_id].presence
    anonymous_id = params[:anonymous_id].presence

    if user_id.blank? && anonymous_id.blank?
      return redirect_to painel_lgpd_path, status: :see_other,
                         alert: "Informe a conta ou o id anônimo do titular."
    end

    escopo = AnalyticsEvent.all
    escopo = escopo.where(user_id: user_id) if user_id
    escopo = escopo.where(anonymous_id: anonymous_id) if anonymous_id
    apagados = escopo.delete_all

    consentimentos = CookieConsent.all
    consentimentos = consentimentos.where(user_id: user_id) if user_id
    consentimentos = consentimentos.where(anonymous_id: anonymous_id) if anonymous_id
    consentimentos.delete_all

    voltar_para painel_lgpd_path, "#{apagados} evento(s) de comportamento eliminados."
  end
end
