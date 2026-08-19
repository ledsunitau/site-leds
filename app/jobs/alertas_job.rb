# Verifica as condições de alerta e avisa a gestão (painel → Alertas).
# Agendado de hora em hora em config/recurring.yml.
#
# As CHECAGENS são fixas em código; só os LIMIARES são configuráveis (linhas de
# Setting, editáveis na tela). Uma regra genérica vinda do banco precisaria de
# um DSL de query próprio ou de Ruby avaliado a partir de uma linha — execução
# arbitrária atrás de um papel que meia dúzia de pessoas tem. Limiar editável
# entrega a calibragem sem essa superfície.
class AlertasJob < ApplicationJob
  queue_as :default

  def perform
    gestores = User.gestao.to_a
    return if gestores.empty?

    disparados = CHECAGENS.filter_map { |checagem| executar(checagem) }
    disparados.each do |alerta|
      AlertaNotifier.with(**alerta).deliver(gestores)
    end
  end

  # Cada checagem devolve o alerta (hash) quando a condição bate, ou nil.
  CHECAGENS = %i[fila_parada denuncias_pendentes erros_recentes pedidos_parados].freeze

  private

  # Uma checagem que estoura não pode derrubar as outras. E o ApplicationJob
  # transforma exceção em ErrorLog — sem este rescue, um alerta quebrado
  # dispararia o alerta DE ERROS na rodada seguinte, em loop.
  def executar(nome)
    send(nome)
  rescue StandardError => e
    Rails.logger.error("AlertasJob: checagem #{nome} falhou — #{e.class}: #{e.message}")
    nil
  end

  def fila_parada
    dias = Setting.limiar("alerta_aprovacoes_dias")
    corte = dias.days.ago
    parados = Post.em_aprovacao.where(updated_at: ...corte).count +
              Ideia.pendentes.where(created_at: ...corte).count
    return if parados.zero?

    {
      titulo: "Fila de aprovação parada",
      mensagem: "#{parados} item(ns) aguardam revisão há mais de #{dias} dia(s).",
      url: "/painel/aprovacoes"
    }
  end

  def denuncias_pendentes
    limite = Setting.limiar("alerta_denuncias")
    total = Denuncia.pendentes.count
    return if total <= limite

    {
      titulo: "Denúncias acumulando",
      mensagem: "#{total} denúncias pendentes (limite configurado: #{limite}).",
      url: "/painel/denuncias"
    }
  end

  def erros_recentes
    limite = Setting.limiar("alerta_erros_hora")
    total = ErrorLog.where(occurred_at: 1.hour.ago.., severidade: %w[error fatal]).count
    return if total <= limite

    {
      titulo: "Pico de erros",
      mensagem: "#{total} erros graves na última hora (limite configurado: #{limite}).",
      url: "/painel/logs"
    }
  end

  def pedidos_parados
    horas = Setting.limiar("alerta_pedidos_horas")
    total = Pedido.pago.where(updated_at: ...horas.hours.ago).count
    return if total.zero?

    {
      titulo: "Pedidos parados",
      mensagem: "#{total} pedido(s) pagos sem avançar há mais de #{horas}h.",
      url: "/painel/pedidos"
    }
  end
end
