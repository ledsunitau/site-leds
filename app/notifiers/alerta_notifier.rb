# Alerta de sistema para a gestão (painel → Alertas). record = nil; o conteúdo
# vem dos params, porque um alerta é sobre um AGREGADO ("12 erros na última
# hora"), não sobre um registro.
#
# SÓ in-app, pelo mesmo motivo do DenunciaNotifier: o alerta dispara a cada
# verificação enquanto a condição durar. Com e-mail/Discord ligados, uma noite
# de erro em loop viraria dezenas de mensagens externas por gestor — o sino e o
# dashboard resolvem sem esse risco, e quem quiser é avisado ao abrir o painel.
class AlertaNotifier < ApplicationNotifier
  CATEGORIA = "sistema".freeze

  def entrega_externa? = false

  def titulo = params[:titulo]
  def mensagem = params[:mensagem]
  def url = params[:url]
end
