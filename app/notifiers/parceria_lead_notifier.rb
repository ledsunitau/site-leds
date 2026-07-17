# Lead de parceria novo (RF-PAR-04): avisa a gestão para triar no dashboard.
# record = o ParceriaLead.
#
# SÓ in-app, por isso sem CATEGORIA: o gatilho é um formulário PÚBLICO sem
# login. Mandar e-mail/push/DM com texto anônimo para todos os gestores seria
# um amplificador de spam (o throttle conta requests, não destinatários) e de
# phishing saindo do nosso próprio remetente confiável. Sem canal de saída não
# há o que preferir — daí não registrar categoria (senão vira ajuste morto).
class ParceriaLeadNotifier < ApplicationNotifier
  def entrega_externa? = false

  def titulo = "Novo contato de parceria"
  def mensagem = "#{record&.empresa} quer conversar sobre #{record&.tipo}."
  def url = "/admin/parceria_leads"
end
