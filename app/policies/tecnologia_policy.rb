class TecnologiaPolicy < ApplicationPolicy
  def index? = true
  def create? = membro_liga?
end
