# RF-LOJ-07: a reserva atingiu a meta e a produção foi disparada — o reservante
# precisa pagar para confirmar a compra. record = o Produto.
class ProducaoDisparadaNotifier < ApplicationNotifier
  CATEGORIA = "loja"

  def titulo = "Sua reserva pode ser paga"
  def mensagem = "\"#{record&.nome}\" atingiu a meta e entrou em produção — pague para confirmar."
  def url = "/reservas"
end
