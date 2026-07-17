# Denúncia nova: avisa a gestão que há o que triar na aba (RF-ADM-05).
# record = a Denuncia.
#
# SÓ in-app (por isso sem CATEGORIA). O spec pede a ABA, não notificação — o
# aviso é cortesia nossa. E a aritmética do ParceriaLeadNotifier vale igual
# aqui: o throttle conta requests, não destinatários. Uma conta (cadastro OAuth
# é grátis) denunciando 20 comentários/h × N gestores × 3 canais vira centenas
# de mensagens externas/h — assédio barato. O sino + a aba resolvem sem abrir
# esse vetor; moderação não tem SLA de minutos.
class DenunciaNotifier < ApplicationNotifier
  def entrega_externa? = false

  def titulo = "Comentário denunciado"
  def mensagem = "Um comentário foi denunciado e aguarda análise."
  def url = "/admin/denuncias"
end
