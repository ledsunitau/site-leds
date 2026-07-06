# RNF-14/RF-ADM-08: toda exceção não tratada vira linha em error_logs antes
# de seguir para o 500 padrão. Erros que o Rails mapeia para 4xx
# (RecordNotFound → 404, ParameterMissing → 400…) são fluxo normal de API,
# não defeito — ficam de fora.
#
# Cobre actions de controllers (com contexto rico: rota, usuário, payload).
# Erro levantado FORA de action (middleware, roteamento) não passa por aqui
# — limitação conhecida; o Rails.error.subscribe cobriria, sem este contexto.
#
# Deve ser incluído ANTES dos rescue_from específicos (Pundit,
# RecordInvalid): o último handler compatível declarado ganha, então os
# específicos continuam respondendo 403/422 sem passar por aqui.
module CapturaDeErros
  extend ActiveSupport::Concern

  # Tempestade (mesmo erro na mesma rota em loop) não pode inundar a tabela:
  # registra as primeiras por minuto e amortece o resto (RNF-14 pede
  # persistência, não um vetor de escrita para scrapers).
  LIMITE_POR_MINUTO = 10

  included do
    rescue_from StandardError, with: :registrar_erro_e_reerguer
  end

  private

  def registrar_erro_e_reerguer(excecao)
    begin
      if erro_de_servidor?(excecao) && !tempestade_de_erros?(excecao)
        ErrorLog.registrar(
          excecao,
          user: current_user,
          rota: "#{request.method} #{request.path}",
          componente: self.class.name,
          acao_tentada: action_name,
          input_payload: payload_mascarado,
          user_agent: request.user_agent
        )
      end
    rescue StandardError => falha_no_log
      # montar o contexto também pode falhar (body JSON malformado, banco
      # fora) — NUNCA substituir a exceção original pela falha do log
      Rails.logger.error("captura de erro falhou: #{falha_no_log.class}: #{falha_no_log.message}")
    end
    raise excecao
  end

  def erro_de_servidor?(excecao)
    ActionDispatch::ExceptionWrapper.status_code_for_exception(excecao.class.name) >= 500
  end

  def tempestade_de_erros?(excecao)
    chave = "error_logs/#{excecao.class.name}:#{request.path}"
    Rails.cache.increment(chave, 1, expires_in: 1.minute).to_i > LIMITE_POR_MINUTO
  end

  # RN-16: filtered_parameters aplica o filter_parameters do app (senhas,
  # tokens…). Valores não escalares (upload de arquivo etc.) viram o nome da
  # classe — jsonb não os serializa e o conteúdo não interessa ao log.
  def payload_mascarado
    request.filtered_parameters.except("controller", "action").deep_transform_values do |valor|
      case valor
      when String, Numeric, TrueClass, FalseClass, NilClass then valor
      else valor.class.name
      end
    end
  end
end
