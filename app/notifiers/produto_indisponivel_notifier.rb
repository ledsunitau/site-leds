# RF-LOJ-08/RN-11: um produto reservado ficou indisponível — avisa quem tinha
# reserva ativa (que o trigger acabou de cancelar). record = o Produto.
# Entrega externa normal: é o cliente querendo saber do PRÓPRIO pedido, não um
# amplificador anônimo — e o gatilho (marcar indisponivel) exige membro logado.
class ProdutoIndisponivelNotifier < ApplicationNotifier
  CATEGORIA = "loja"

  def titulo = "Produto reservado ficou indisponível"
  def mensagem = "Sua reserva de \"#{record&.nome}\" foi cancelada: o produto saiu do ar."
  def url = "/reservas"
end
