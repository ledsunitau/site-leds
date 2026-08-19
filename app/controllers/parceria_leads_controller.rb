# Formulário público "seja um parceiro" (RF-PAR-03): cria um LEAD, que cai no
# dashboard da gestão (RF-PAR-04). Não cria parceiro — a conversão é decisão da
# liga. Público e sem sessão; throttle em rack_attack.rb.
class ParceriaLeadsController < ApplicationController
  # Formulário público sem sessão a proteger (mesmo motivo de consents/events):
  # o CSRF só quebraria o cliente legítimo.
  skip_forgery_protection

  include RecursoAtivo
  exige_recurso "parceria_ativa", only: :create

  def create
    @lead = ParceriaLead.new(params.expect(parceria_lead: %i[empresa contato_nome contato_email tipo descricao]))
    if @lead.save
      respond_to do |format|
        # resposta mínima: é um formulário público, não expõe a fila da gestão
        format.json { render json: { id: @lead.id, status: @lead.status }, status: :created }
        format.html { redirect_to parceiros_path(anchor: "seja-parceiro"), notice: "Recebemos seu interesse! Em breve a gente fala com você. 🤝" }
      end
    else
      respond_to do |format|
        format.json { render_invalido(@lead) }
        format.html { redirect_to parceiros_path(anchor: "seja-parceiro"), alert: @lead.errors.full_messages.to_sentence }
      end
    end
  end
end
