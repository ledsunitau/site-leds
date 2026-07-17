# RF-PAR-04: dashboard dos leads de parceria, atrás do gate de gestão.
# converter transforma o lead aceito num Parceiro da vitrine (RF-PAR-01).
class Admin::ParceriaLeadsController < Admin::BaseController
  def index
    # sem includes(:parceiro): lead_json lê parceiro_id, coluna da própria linha
    leads = ParceriaLead.order(created_at: :desc)
    leads = leads.where(status: filtro(:status)) if filtro(:status)
    leads = leads.where(tipo: filtro(:tipo)) if filtro(:tipo)

    render json: { leads: paginar(leads, por_pagina: 50).map { |l| lead_json(l) } }
  end

  # Aceita o lead: cria o parceiro e amarra os dois.
  def converter
    lead = ParceriaLead.find(params[:id])
    parceiro = lead.converter!

    render json: lead_json(lead).merge(parceiro: parceiro.card_json)
  end

  def recusar
    lead = ParceriaLead.find(params[:id])
    lead.recusar!

    render json: lead_json(lead)
  end

  # LGPD art. 18 (eliminação): o lead guarda nome/e-mail de uma pessoa que
  # pediu contato. Sem esta ação, atender um pedido de exclusão exigiria
  # console de produção. O parceiro já convertido sobrevive (FK nullify).
  def destroy
    ParceriaLead.find(params[:id]).destroy!
    head :no_content
  end

  private

  def lead_json(lead)
    {
      id: lead.id,
      empresa: lead.empresa,
      contato_nome: lead.contato_nome,
      contato_email: lead.contato_email,
      tipo: lead.tipo,
      descricao: lead.descricao,
      status: lead.status,
      parceiro_id: lead.parceiro_id,
      criado_em: lead.created_at
    }
  end
end
