# RF-AUT-08/RN-15: concessão de papéis (regras na UserPolicy) e busca de
# contas para administrar (RF-ADM-03).
class Admin::UsersController < Admin::BaseController
  def index
    users = User.includes(:member).order(:name, :id)
    users = users.where(role: filtro(:role)) if filtro(:role)
    if filtro(:busca)
      termo = "%#{User.sanitize_sql_like(filtro(:busca))}%"
      users = users.where(User.arel_table[:name].matches(termo).or(User.arel_table[:email].matches(termo)))
    end

    render json: { users: paginar(users, por_pagina: 50).map { |u| user_json(u) } }
  end

  def update
    user = User.find(params[:id])
    novo_role = params.require(:user).require(:role).to_s

    unless policy(user).atualizar_role?(novo_role)
      raise Pundit::NotAuthorizedError # rescue_from padrão -> 403
    end

    user.update!(role: novo_role)
    render json: user_json(user)
  end

  private

  def user_json(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      member_id: user.member&.id
    }
  end
end
