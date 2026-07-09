# RF-NOV-04/RN-02: notícia = membro+; blog = escritores também; aprovar e
# rejeitar = diretoria+. Autor só mexe no que é dele.
class PostPolicy < ApplicationPolicy
  def index? = true

  def show?
    record.publicado? || dono? || gestor?
  end

  def create? = pode_escrever?

  def update?
    gestor? || (dono? && pode_escrever?)
  end

  # publicado só sai do ar pela mão da gestão
  def destroy?
    gestor? || (dono? && !record.publicado?)
  end

  def submeter? = dono? || gestor?
  def aprovar? = gestor?
  def rejeitar? = aprovar?
  def versoes? = dono? || gestor?

  private

  # Notícia: membro da liga ou acima. Blog: escritores também (RF-NOV-04).
  def pode_escrever?
    return false if user.nil?
    # tipo ausente/inválido: libera para quem escreve QUALQUER tipo — a
    # validação do enum responde 422 (403 aqui mascararia o erro real)
    return user.escritor? || membro_liga? unless Post::TIPOS.include?(record.tipo)

    record.blog? ? (user.escritor? || membro_liga?) : membro_liga?
  end
end
