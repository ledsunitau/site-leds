# RF-NOV-09: qualquer usuário logado denuncia um comentário. Ver e resolver a
# fila é da gestão (RF-ADM-05, atrás do Admin::BaseController).
class DenunciaPolicy < ApplicationPolicy
  def create? = user.present?
end
