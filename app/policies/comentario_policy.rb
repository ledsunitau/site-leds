# RF-NOV-08/10: qualquer usuário logado comenta em post publicado; ler é
# público (o controller escopa para os visíveis). Ocultar/remover é da gestão.
class ComentarioPolicy < ApplicationPolicy
  def index? = true
  def create? = user.present?

  # RF-NOV-10: tirar do ar é ato de gestão (registra moderated_by/at)
  def moderar? = gestor?
end
