# Triagem dos leads de parceria (RF-PAR-04). Converter transforma o lead aceito
# num Parceiro da vitrine (RF-PAR-01); recusar encerra; excluir atende pedido de
# eliminação (LGPD art. 18) — o lead guarda nome e e-mail de uma pessoa.
class Painel::LeadsController < Painel::BaseController
  POR_PAGINA = 40

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)
    @tipo = filtro(:tipo)

    escopo = ParceriaLead.includes(:parceiro).order(created_at: :desc)
    escopo = escopo.where(status: @status) if @status
    escopo = escopo.where(tipo: @tipo) if @tipo

    @leads = paginar(escopo, por_pagina: POR_PAGINA)
    @por_status = ParceriaLead.group(:status).count
  end

  def converter
    lead = ParceriaLead.find(params[:id])
    parceiro = lead.converter!
    voltar_para painel_parceiros_path, "“#{parceiro.nome}” virou parceiro — ajuste logo e site na ficha."
  end

  def recusar
    lead = ParceriaLead.find(params[:id])
    lead.recusar!
    voltar_para painel_leads_path, "Lead recusado."
  end

  def destroy
    lead = ParceriaLead.find(params[:id])
    lead.destroy!
    voltar_para painel_leads_path, "Lead eliminado — os dados de contato saíram do banco."
  end
end
