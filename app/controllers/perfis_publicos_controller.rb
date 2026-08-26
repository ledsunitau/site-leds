# Página pública de um usuário (RF-EMB): emblemas equipados, projetos que
# participou e avaliações de produto que fez.
#
# "Pública" no sentido de "de outra pessoa", não de "aberta à internet": exige
# login como a loja (RN-17) — as avaliações citam produto e nota. E-mail nunca
# aparece aqui: quem quiser o contato usa a ficha de membro.
class PerfisPublicosController < ApplicationController
  before_action :authenticate_user!

  def show
    @usuario = User.includes(:emblema_destaque, :emblema_secundario, :emblema_nome, :emblema_halo,
                             :member, :elo,
                             foto_attachment: :blob).find(params[:id])
    authorize @usuario, :show?

    # conquistas junto: é o hover que lista "todas as maratonas que essa pessoa
    # participou" — sem o preload seria uma consulta por emblema
    @vinculos = EmblemaUsuario.where(user: @usuario)
                              .includes(:conquistas, { nivel: :rank }, :emblema)
                              .sort_by { |v| [ v.emblema.usuarios_count, v.emblema.nome ] }
    @acoes = @usuario.acoes_creditadas.includes(:detalhe, thumbnail_attachment: :blob)
    @avaliacoes = @usuario.avaliacoes.recentes.includes(produto: { imagem_attachment: :blob })
  end
end
