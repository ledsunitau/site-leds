# Ideia nova proposta pela comunidade (RF-IDE-04): avisa a gestão para revisar.
# record = a Ideia.
class IdeiaPropostaNotifier < ApplicationNotifier
  CATEGORIA = "ideias"

  def titulo = "Nova ideia para revisar"
  def mensagem = "\"#{record&.titulo}\" foi proposta pela comunidade."
  def url = "/admin/approvals"
end
