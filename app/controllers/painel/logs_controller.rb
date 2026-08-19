# Log de erros (RF-ADM-08/09, RNF-14). Busca por severidade, rota, usuário e
# período; o detalhe traz payload mascarado (RN-16) e backtrace.
class Painel::LogsController < Painel::BaseController
  POR_PAGINA = 50

  # Colunas gordas (backtrace, input_payload) ficam fora do SELECT da lista —
  # só o detalhe lê. Ordena por id: a tabela é insert-only, então o id segue
  # occurred_at e o scan reverso sai pela PK.
  COLUNAS_DA_LISTA = %i[id occurred_at rota componente acao_tentada error_class
                        error_message severidade ambiente user_id].freeze

  def index
    @pendencias = PainelMetricas.new.pendencias
    @severidade = filtro(:severidade)
    @rota = filtro(:rota)

    escopo = ErrorLog.select(*COLUNAS_DA_LISTA).includes(:user).order(id: :desc)
    escopo = escopo.where(severidade: @severidade) if @severidade
    escopo = escopo.where(ErrorLog.arel_table[:rota].matches("%#{ErrorLog.sanitize_sql_like(@rota)}%")) if @rota
    escopo = escopo.where(user_id: filtro(:user_id)) if filtro(:user_id)
    escopo = filtrar_por_periodo(escopo, :occurred_at)

    @logs = paginar(escopo, por_pagina: POR_PAGINA)
    @por_severidade = ErrorLog.group(:severidade).count
    @por_dia = PainelMetricas.new.erros_por_dia
  end

  def show
    @log = ErrorLog.find(params[:id])
  end
end
