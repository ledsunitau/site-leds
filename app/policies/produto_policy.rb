# Loja (RN-17/RF-INI-11): padrão EXCLUSIVO da loja — o item aparece no header
# para todos, mas VER o conteúdo exige login. Diferente do resto do site, que é
# público. Por isso index?/show? pedem usuário, e não `true`.
#
# Criar/editar produto é membro da liga para cima (matriz de permissões +
# RN-13, auditado) — parceiro e escritor compram, mas não cadastram.
class ProdutoPolicy < ApplicationPolicy
  def index? = user.present?

  # Indisponível sai da vitrine E do acesso por id — senão o index filtra e o
  # show entrega o produto retirado a quem tiver o link (mesma regra do
  # ParceiroPolicy#show?/AcaoPolicy#show?). Quem cadastra segue enxergando.
  def show? = user.present? && (record.ativo? || create?)

  def create? = membro_liga?
  def update? = create?
end
