# Cadastro por e-mail/senha. Existe só para o painel poder fechar a porta
# (Recursos → "Cadastro de novas contas"); o resto é o Devise padrão.
#
# O outro caminho de cadastro é o OAuth, que cria conta direto no callback —
# guardado lá também (Users::OmniauthCallbacksController#user_for). Flagar só
# este deixaria Google e Discord abertos.
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :cadastro_aberto!, only: %i[new create]

  private

  def cadastro_aberto!
    return if Setting.ativo?("cadastro_publico")

    redirect_to new_user_session_path,
                alert: "O cadastro de novas contas está temporariamente fechado."
  end
end
