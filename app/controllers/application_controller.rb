class ApplicationController < ActionController::Base
  # ANTES dos rescue_from específicos: o último handler compatível ganha,
  # então Pundit/RecordInvalid seguem 403/422 sem virar error_log.
  include CapturaDeErros
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError do
    head :forbidden
  end

  # Contrato único de erro de validação (render_invalido) para todo save!.
  rescue_from ActiveRecord::RecordInvalid do |e|
    render_invalido(e.record)
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

  # Data ISO vinda de query string; inválida/ausente vira nil.
  def data_do_filtro(chave)
    Date.iso8601(filtro(chave)) if filtro(chave)
  rescue Date::Error
    nil
  end

  # Paginação simples por query string (?pagina=N). O clamp de cima importa:
  # sem ele, um número gigante estoura o bigint do OFFSET (500 público).
  def paginar(escopo, por_pagina: 20)
    pagina = filtro(:pagina).to_i.clamp(1, 100_000)
    escopo.limit(por_pagina).offset((pagina - 1) * por_pagina)
  end

  # Janela ?de=/&ate= (ISO) sobre uma coluna de timestamp.
  def filtrar_por_periodo(escopo, coluna)
    de = data_do_filtro(:de)
    ate = data_do_filtro(:ate)
    escopo = escopo.where(coluna => de.beginning_of_day..) if de
    escopo = escopo.where(coluna => ..ate.end_of_day) if ate
    escopo
  end

  # Diff de uma versão do PaperTrail sem o ruído de timestamps/id. Lista de
  # exclusão ÚNICA (posts#versoes e admin/audits): mascarar um atributo
  # sensível aqui vale para as duas telas.
  def mudancas_da_versao(versao)
    versao.object_changes&.except("updated_at", "created_at", "id")
  end

  # Contrato único de erro de validação da API JSON.
  def render_invalido(registro)
    render json: { errors: registro.errors.full_messages }, status: :unprocessable_entity
  end

  # Ações que gravam autoria/aprovação precisam do perfil Member do usuário
  # (role pode ser promovida antes do perfil existir). Renderiza o 422 e
  # devolve nil quando falta — chamador faz `return if membro.nil?`.
  def exigir_member!
    membro = current_user.member
    if membro.nil?
      render json: { errors: [ "Seu usuário ainda não tem perfil de membro cadastrado." ] },
             status: :unprocessable_entity
    end
    membro
  end
end
