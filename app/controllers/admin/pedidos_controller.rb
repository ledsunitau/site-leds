# RF-LOJ-04 (tracking, transições de gestão): a diretoria acompanha e avança os
# pedidos. Envio/entrega automáticos vêm do Melhor Envio (EtiquetaJob e
# RastreioUpdateJob); aqui a gestão marca 'em produção' e pode registrar um envio
# manual (quando a etiqueta não sai pela API — ex.: frete não configurado).
class Admin::PedidosController < Admin::BaseController
  # RecordInvalid (transição inválida) vira 422 pelo handler do ApplicationController.

  def index
    pedidos = Pedido.includes(:endereco, itens: %i[produto variante]).order(created_at: :desc)
    pedidos = pedidos.where(status: params[:status]) if params[:status].present?
    render json: { pedidos: paginar(pedidos, por_pagina: 50).map(&:card_json) }
  end

  def em_producao
    pedido = Pedido.find(params[:id])
    pedido.marcar_em_producao!
    render json: pedido.card_json
  end

  # Envio manual: registra o código de rastreio quando a etiqueta não veio da API
  # (ex.: frete não configurado, ou CPF do destinatário ainda não coletado).
  def enviar
    pedido = Pedido.find(params[:id])
    pedido.marcar_enviado!(params.require(:rastreamento_codigo))
    render json: pedido.card_json
  end

  # Entrega manual: fecha o ciclo de um envio despachado à mão (sem melhor_envio_ref,
  # que o RastreioUpdateJob não acompanha).
  def entregar
    pedido = Pedido.find(params[:id])
    pedido.marcar_entregue!
    render json: pedido.card_json
  end
end
