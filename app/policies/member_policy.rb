# Leitura pública (cards, grafo, geneograma); gestão de membros/cargos é da
# diretoria e presidência (RF-ADM-03 — controllers de escrita na branch admin).
class MemberPolicy < ApplicationPolicy
  def index? = true
  def show? = true

  def create? = gestor?
  def update? = gestor?
  def destroy? = gestor?
end
