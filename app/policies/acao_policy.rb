# RN-13: membros e acima criam/editam Ações (auditado via PaperTrail);
# leitura pública só do que está publicado; arquivar é da diretoria+.
class AcaoPolicy < ApplicationPolicy
  def index? = true

  def show?
    record.publicada? || membro_liga?
  end

  def create? = membro_liga?
  def update? = membro_liga?
  def arquivar? = gestor?
end
