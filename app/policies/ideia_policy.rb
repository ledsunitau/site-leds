# RF-IDE/RN-01: qualquer usuário logado propõe uma ideia; revisar (aprovar/
# rejeitar) é da gestão (RF-IDE-04). O autor vê a sua; a gestão vê todas.
class IdeiaPolicy < ApplicationPolicy
  def index? = user.present? # o controller escopa (minhas vs. fila da gestão)
  def show? = dono? || gestor?
  def create? = user.present? # a comunidade propõe

  def aprovar? = gestor?
  def rejeitar? = aprovar?
end
