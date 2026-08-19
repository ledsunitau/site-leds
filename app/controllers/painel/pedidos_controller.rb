# Pedidos (RF-LOJ-04): acompanhamento e transições de fulfillment.
#
# Envio e entrega normalmente vêm do Melhor Envio (EtiquetaJob/RastreioUpdateJob);
# aqui a gestão marca "em produção" e registra envio/entrega à mão para quando a
# etiqueta não sai pela API (frete não configurado, retirada no campus).
class Painel::PedidosController < Painel::BaseController
  POR_PAGINA = 40

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)

    escopo = Pedido.includes(:comprador, :endereco, :pagamentos, itens: %i[produto variante])
                   .order(created_at: :desc)
    escopo = escopo.where(status: @status) if @status

    @pedidos = paginar(escopo, por_pagina: POR_PAGINA)
    @por_status = Pedido.group(:status).count
    @receita = Pedido.where(status: Pedido::PAGOS).sum(:total)
  end

  # Baixa manual de pagamento. No modo "direto" (Recursos → pagamento da loja) a
  # cobrança acontece FORA do site — pessoalmente, no campus — então não existe
  # webhook para mover o pedido. Sem esta ação, um pedido pago na mão ficava
  # preso em aguardando_pagamento e a ExpirarPedidosJob o cancelava em 1h.
  #
  # É o MESMO caminho do gateway (Pedido#marcar_pago!): converte a reserva,
  # avisa o comprador e, se for envio, agenda a etiqueta.
  def marcar_pago
    pedido = Pedido.find(params[:id])
    pedido.marcar_pago!
    voltar_para painel_pedidos_path,
                "Pedido ##{pedido.id} marcado como pago — o comprador foi avisado."
  end

  # A gestão cancela pelo comprador (desistência combinada por fora). Devolve o
  # estoque reservado, como o cancelamento do próprio cliente.
  def cancelar
    pedido = Pedido.find(params[:id])
    pedido.cancelar!
    voltar_para painel_pedidos_path, "Pedido ##{pedido.id} cancelado — o estoque voltou."
  end

  def em_producao
    pedido = Pedido.find(params[:id])
    pedido.marcar_em_producao!
    voltar_para painel_pedidos_path, "Pedido ##{pedido.id} em produção."
  end

  def enviar
    pedido = Pedido.find(params[:id])
    codigo = params[:rastreamento_codigo].to_s.strip
    if codigo.blank?
      return redirect_to painel_pedidos_path, status: :see_other,
                         alert: "Informe o código de rastreio para marcar como enviado."
    end

    pedido.marcar_enviado!(codigo)
    voltar_para painel_pedidos_path, "Pedido ##{pedido.id} enviado — o comprador foi avisado."
  end

  def entregar
    pedido = Pedido.find(params[:id])
    pedido.marcar_entregue!
    voltar_para painel_pedidos_path, "Pedido ##{pedido.id} entregue."
  end
end
