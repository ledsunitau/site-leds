# RF-ADM-08/09: busca no log de erros por usuário, período, rota e
# severidade. O detalhe (show) traz payload e backtrace; a lista, não.
class Admin::ErrorLogsController < Admin::BaseController
  # Sem backtrace/payload no SELECT da lista (colunas gordas, só o show lê);
  # ordena por id (tabela insert-only: id segue occurred_at e usa a PK).
  COLUNAS_DA_LISTA = %i[id occurred_at rota componente acao_tentada error_class
                        error_message severidade ambiente user_id].freeze

  def index
    logs = ErrorLog.select(*COLUNAS_DA_LISTA).includes(:user).order(id: :desc)
    logs = logs.where(user_id: filtro(:user_id)) if filtro(:user_id)
    logs = logs.where(severidade: filtro(:severidade)) if filtro(:severidade)
    logs = logs.where(ErrorLog.arel_table[:rota].matches("%#{ErrorLog.sanitize_sql_like(filtro(:rota))}%")) if filtro(:rota)
    logs = filtrar_por_periodo(logs, :occurred_at)

    render json: { error_logs: paginar(logs, por_pagina: 50).map { |log| resumo_json(log) } }
  end

  def show
    log = ErrorLog.find(params[:id])
    render json: resumo_json(log).merge(
      input_payload: log.input_payload,
      backtrace: log.backtrace,
      user_agent: log.user_agent
    )
  end

  private

  def resumo_json(log)
    {
      id: log.id,
      occurred_at: log.occurred_at,
      rota: log.rota,
      componente: log.componente,
      acao_tentada: log.acao_tentada,
      error_class: log.error_class,
      error_message: log.error_message,
      severidade: log.severidade,
      ambiente: log.ambiente,
      user: log.user && { id: log.user.id, name: log.user.name }
    }
  end
end
