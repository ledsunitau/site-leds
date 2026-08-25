# RF-EMB: avisa o usuário que desbloqueou um emblema. record = o Emblema.
# Categoria "sistema" (já existente): não vale abrir uma linha nova de
# preferência por canal só para isto.
class EmblemaConcedidoNotifier < ApplicationNotifier
  CATEGORIA = "sistema"

  def titulo = "Você desbloqueou um emblema"
  def mensagem = "“#{record&.nome}” agora é seu. Equipe-o no seu perfil."
  def url = "/emblemas"
end
