class CongressoPolicy < ApplicationPolicy
  def index? = true
  def create? = membro_liga?
end
