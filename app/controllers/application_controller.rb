class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError do
    head :forbidden
  end

  # O sanitizer padrão do Devise só permite email/senha; sem isto o `name`
  # (NOT NULL) é descartado e nenhum cadastro por e-mail/senha funciona.
  before_action :configure_permitted_parameters, if: :devise_controller?

  # PaperTrail: registra quem fez cada mudança auditada (RF-ADM-07)
  before_action :set_paper_trail_whodunnit

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  # Filtros vindos de query string pública: só valores escalares
  # (hash/array dentro de where() levanta TypeError -> 500).
  def filtro(chave)
    valor = params[chave]
    valor if valor.is_a?(String) && valor.present?
  end

  # Contrato único de erro de validação da API JSON.
  def render_invalido(registro)
    render json: { errors: registro.errors.full_messages }, status: :unprocessable_entity
  end
end
