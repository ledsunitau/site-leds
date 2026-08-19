# Contas e papéis (RF-ADM-03/RF-AUT-08). A regra de quem pode conceder o quê
# está na UserPolicy (RN-15) e continua sendo a autoridade: a tela apenas
# esconde o controle que o servidor recusaria.
class Painel::UsuariosController < Painel::BaseController
  POR_PAGINA = 40

  def index
    @pendencias = PainelMetricas.new.pendencias
    @role = filtro(:role)
    @busca = filtro(:busca)

    escopo = User.includes(:member).order(:name, :id)
    escopo = escopo.where(role: @role) if @role
    if @busca
      termo = "%#{User.sanitize_sql_like(@busca)}%"
      escopo = escopo.where(User.arel_table[:name].matches(termo).or(User.arel_table[:email].matches(termo)))
    end

    @usuarios = paginar(escopo, por_pagina: POR_PAGINA)
    @contagem = User.group(:role).count
  end

  def update
    usuario = User.find(params[:id])
    novo_role = params.require(:user).require(:role).to_s

    # RN-15: papel DE gestão (dar ou tirar) é só da presidência, e ninguém
    # muda o próprio. Sem este guard a tela seria a autoridade — e ela mente.
    unless policy(usuario).atualizar_role?(novo_role)
      return redirect_back fallback_location: painel_usuarios_path, status: :see_other,
                           alert: "Você não pode conceder ou remover esse papel."
    end

    usuario.update!(role: novo_role)
    redirect_back fallback_location: painel_usuarios_path, status: :see_other,
                  notice: "#{usuario.name} agora é #{helpers.papel_label(novo_role)}."
  end
end
