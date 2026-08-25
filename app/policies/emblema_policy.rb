# Emblemas (RF-EMB): catálogo e perfil público são leitura de quem está logado
# (mesmo padrão da loja, RN-17). Criar, editar e conceder é da gestão.
class EmblemaPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = user.present?

  def create? = gestor?
  def update? = gestor?
  def conceder? = gestor?
  def revogar? = gestor?

  # Emblema com dono é histórico de conquista alheia: só sai enquanto ninguém
  # tem. Para tirar de circulação existe `ativo: false`.
  def destroy? = gestor? && record.usuarios_count.zero?
end
