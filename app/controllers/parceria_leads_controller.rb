# Formulário público "seja um parceiro" (RF-PAR-03): cria um LEAD, que cai no
# dashboard da gestão (RF-PAR-04). Não cria parceiro — a conversão é decisão da
# liga. Público e sem sessão; throttle em rack_attack.rb.
class ParceriaLeadsController < ApplicationController
  # Formulário público sem sessão a proteger (mesmo motivo de consents/events):
  # o CSRF só quebraria o cliente legítimo.
  skip_forgery_protection

  def create
    lead = ParceriaLead.create!(params.expect(parceria_lead: %i[empresa contato_nome contato_email tipo descricao]))

    # resposta mínima: é um formulário público, não expõe a fila da gestão
    render json: { id: lead.id, status: lead.status }, status: :created
  end
end
