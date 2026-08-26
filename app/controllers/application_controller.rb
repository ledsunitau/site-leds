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

  # Corrida em índice único: dois creates concorrentes passam a validação
  # app-level (leram antes do outro inserir) e colidem no banco. Vira 422 amigável
  # em vez de 500. O caso comum (não-concorrente) já é pego pela validação com a
  # mensagem específica; aqui é o backstop raro da corrida.
  rescue_from ActiveRecord::RecordNotUnique do
    render json: { errors: [ "Registro duplicado: já existe um igual." ] },
           status: :unprocessable_entity
  end

  # O sanitizer padrão do Devise só permite email/senha; sem isto o `name`
  # (NOT NULL) é descartado e nenhum cadastro por e-mail/senha funciona.
  before_action :configure_permitted_parameters, if: :devise_controller?

  # PaperTrail: registra quem fez cada mudança auditada (RF-ADM-07)
  before_action :set_paper_trail_whodunnit

  # Modo manutenção (painel → Recursos): fecha o site para quem não é gestão.
  before_action :bloquear_em_manutencao

  # Depois do render: a essa altura o respond_to já pôs o Vary: Accept dele, e
  # este soma o Turbo-Frame em vez de substituir (ver render_em_frame).
  after_action :declarar_variacao_de_frame

  protected

  # Quem passa mesmo em manutenção:
  #   - gestão (é quem vai consertar; cobre /painel e /admin, que já exigem isso)
  #   - telas do Devise (senão ninguém consegue LOGAR para virar gestão)
  #   - o webhook do gateway — bloquear perde confirmação de pagamento que o
  #     Mercado Pago não repete para sempre (skip_before_action lá, não aqui)
  # /up não passa por aqui: é o controller interno do Rails, não herda deste.
  def bloquear_em_manutencao
    return if devise_controller?
    return unless Setting.ativo?("manutencao")
    return if current_user&.gestao?

    aviso = "O site está em manutenção. Já voltamos."
    respond_to do |format|
      format.json { render json: { errors: [ aviso ] }, status: :service_unavailable }
      format.html { render "shared/manutencao", status: :service_unavailable, layout: false }
    end
  end

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

  # Página pedida na query string, saneada. O clamp de cima importa: sem ele, um
  # número gigante estoura o bigint do OFFSET (500 público).
  def pagina_atual(param = :pagina)
    filtro(param).to_i.clamp(1, 100_000)
  end

  # Paginação simples por query string (?pagina=N).
  def paginar(escopo, por_pagina: 20, param: :pagina)
    escopo.limit(por_pagina).offset((pagina_atual(param) - 1) * por_pagina)
  end

  # Busca pública por LIKE, sem case (?q=), em UMA OU MAIS colunas (OR entre
  # elas). Escapa os curingas do LIKE: sem isso um "%" digitado casa com tudo e
  # um "_" casa com qualquer caractere.
  #
  # Mais de uma coluna importa quando o card mostra um campo e o banco guarda
  # outro: o card de novidade exibe `caller` e cai em `titulo` — procurar só em
  # titulo faria a busca falhar exatamente no texto que a pessoa está lendo.
  #
  # ponytail: ILIKE '%termo%' não usa índice btree — em algumas centenas de
  # linhas o seq scan é irrelevante; se crescer, pg_trgm + índice GIN.
  def buscar_por(escopo, *colunas, param: :q)
    termo = filtro(param)
    return escopo if termo.blank?

    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(termo)}%"
    # arel matches → ILIKE no PostgreSQL, e sem interpolar nome de coluna em SQL.
    tabela = escopo.arel_table
    escopo.where(colunas.map { |c| tabela[c].matches(padrao) }.reduce(:or))
  end

  # Quantas páginas o escopo tem, para desenhar o pager. COUNT à parte porque o
  # escopo já paginado perdeu o total. Mínimo 1: lista vazia é "página 1 de 1",
  # e assim o pager some (a view esconde quando total <= 1) em vez de mostrar 0.
  def total_de_paginas(escopo, por_pagina:)
    [ (escopo.count.to_f / por_pagina).ceil, 1 ].max
  end

  # Listagem que responde a página INTEIRA ou só o fragmento, conforme o header
  # Turbo-Frame — a mesma URL com dois corpos.
  #
  # Só marca a intenção; quem escreve o header é o after_action. Escrever aqui
  # NÃO funciona: neste ponto o `respond_to` ainda não pôs o `Vary: Accept` dele,
  # e a atribuição some com o Accept em vez de somar a ele.
  def render_em_frame(partial)
    @varia_por_frame = true
    render partial: partial, layout: false if turbo_frame_request?
  end

  # Declara Turbo-Frame como dimensão de variação da resposta.
  #
  # Não é detalhe: em produção tem Cloudflare na frente (ver docs/deploy.md). O
  # CF não cacheia HTML por padrão, mas uma regra "Cache Everything" passaria a
  # cachear por URL — e sem isto serviria o fragmento sem navbar para quem abriu
  # a página pelo endereço, ou a página inteira dentro de um frame.
  #
  # Vale para as DUAS respostas: é a URL que varia, não uma das versões dela.
  def declarar_variacao_de_frame
    return unless @varia_por_frame

    valores = response.headers["Vary"].to_s.split(",").map(&:strip).reject(&:empty?)
    return if valores.any? { |v| v.casecmp?("Turbo-Frame") }

    response.headers["Vary"] = (valores + [ "Turbo-Frame" ]).join(", ")
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

  # Upsert idempotente sob corrida: dois requests concorrentes com a mesma
  # chave única fazem o segundo pegar RecordNotUnique (o find_or_initialize não
  # viu a linha que o outro acabou de inserir). Reexecuta uma vez — agora a
  # linha existe e o find a encontra — em vez de estourar 500.
  def com_upsert_concorrente
    tentativas = 0
    begin
      yield
    rescue ActiveRecord::RecordNotUnique
      (tentativas += 1) <= 1 ? retry : raise
    end
  end

  # Id anônimo do visitante (RNF-04/05). Cookie ASSINADO para não ser forjável
  # (senão dá para atribuir eventos a outro id e inflar visitantes_unicos).
  # Só LÊ — quem cria/persiste o cookie é o ConsentsController. Compartilhado
  # por consents e events: a leitura assinada precisa ser idêntica nos dois,
  # ou a coleta cai em silêncio (id da coleta ≠ id do consentimento).
  def anonymous_id
    cookies.signed[:anonymous_id].presence
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
