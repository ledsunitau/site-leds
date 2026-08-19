# Reservas do modo sob demanda (RF-LOJ-05/06/07). Não existia superfície de
# gestão nenhuma: o DisparoProducaoJob rodava sozinho ao cruzar a meta e a
# diretoria não tinha como ver o progresso nem disparar antes da hora.
class Painel::ReservasController < Painel::BaseController
  def index
    @pendencias = PainelMetricas.new.pendencias
    @metricas = PainelMetricas.new
    @progresso = @metricas.loja[:reservas]

    @reservas = Reserva.includes(:user, :produto, :variante, :pedido)
                       .order(created_at: :desc)
                       .limit(200)
  end

  # Disparo manual: avisa os reservantes para pagar mesmo sem ter cruzado a
  # meta (a liga decidiu produzir assim mesmo). O job é o mesmo que roda no
  # cruzamento automático — não há um segundo caminho de notificação.
  def disparar
    produto = Produto.find(params[:id])

    unless produto.sob_demanda?
      return redirect_to painel_reservas_path, status: :see_other,
                         alert: "“#{produto.nome}” não é sob demanda — não há reservas a avisar."
    end

    DisparoProducaoJob.perform_later(produto.id)
    voltar_para painel_reservas_path, "Aviso de produção enfileirado para os reservantes de “#{produto.nome}”."
  end
end
