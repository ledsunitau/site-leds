# RF-NOV-04/RN-02: notícia = membro+ e jornalistas; blog = membro+ e escritores;
# aprovar e rejeitar = diretoria+. Autor só mexe no que é dele.
#
# Esta é a ÚNICA fonte de "quem escreve o quê": a tela de escrita, o select de
# tipo e o botão em /novidades derivam daqui (ver PostsController#tipos_permitidos
# e HomeHelper#pode_escrever_novidade?), nunca de um `if role ==` próprio.
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

  # Membro da liga escreve os dois tipos. Fora da liga, o papel diz qual:
  # escritor → blog, jornalista → notícia (RF-NOV-04).
  def pode_escrever?
    return false if user.nil?
    # tipo ausente/inválido: libera para quem escreve QUALQUER tipo — a
    # validação do enum responde 422 (403 aqui mascararia o erro real)
    return user.escritor? || user.jornalista? || membro_liga? unless Post::TIPOS.include?(record.tipo)

    record.blog? ? (user.escritor? || membro_liga?) : (user.jornalista? || membro_liga?)
  end
end
