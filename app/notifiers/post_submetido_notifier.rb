# Post entrou na fila de aprovação (RN-02): avisa a gestão (RF-ADM-04).
# record = o Post submetido.
class PostSubmetidoNotifier < ApplicationNotifier
  CATEGORIA = "moderacao"

  def titulo = "Novo post aguardando aprovação"
  # record& : o post pode ter sido apagado entre o evento e a entrega/leitura
  def mensagem = "\"#{record&.titulo}\" entrou na fila de aprovação."
  def url = "/admin/approvals"
end
