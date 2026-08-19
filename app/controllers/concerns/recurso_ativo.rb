# Portão de recurso (painel → Recursos). Um recurso desligado responde 503 no
# JSON e devolve o visitante com um aviso no HTML.
#
# Cada flag precisa de um ponto de leitura REAL — desligar na tela sem guardar a
# rota só esconderia o botão, e o endpoint seguiria aceitando.
module RecursoAtivo
  extend ActiveSupport::Concern

  class_methods do
    # exige_recurso "ideias_ativas", only: %i[new create]
    def exige_recurso(chave, **opcoes)
      before_action(**opcoes) { recurso_ativo!(chave) }
    end
  end

  private

  def recurso_ativo!(chave)
    return if Setting.ativo?(chave)

    aviso = "#{Setting::FLAGS.fetch(chave)[:label]} está temporariamente desativado."
    respond_to do |format|
      format.json { render json: { errors: [ aviso ] }, status: :service_unavailable }
      format.html { redirect_back fallback_location: root_path, alert: aviso, status: :see_other }
    end
  end
end
