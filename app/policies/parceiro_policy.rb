# RF-PAR-01/02: a vitrine e o perfil são públicos, mas só do parceiro ATIVO —
# inativo sai do site (mesma regra do AcaoPolicy#show?/PostPolicy#show?, senão
# o index esconde e o show entrega por id). Editar é da gestão ou da conta
# vinculada (dono?, RF-PAR-05). Criar direto é da gestão — o caminho normal é
# converter um lead.
class ParceiroPolicy < ApplicationPolicy
  def index? = true

  def show?
    record.ativo? || gerenciar? || dono?
  end

  def create? = gerenciar?
  # dono? = parceiros.user_id == user.id (a conta vinculada)
  def update? = gerenciar? || dono?

  # "manda no parceiro": status, vínculo de conta e filtro por status no index.
  # Predicado próprio — pendurar isso em create? acopla o gate de privilégio a
  # uma pergunta diferente ("pode criar?"), que um dia pode ser afrouxada.
  def gerenciar? = gestor?
end
