# RN-15/RF-AUT-08: papéis especiais (escritor etc.) são concedidos pela
# gestão; papéis DE gestão (dar OU tirar) só pela presidência; ninguém
# altera o próprio papel. A regra mora aqui para qualquer caminho futuro
# que toque role (convites, promoções) reusar em vez de reimplementar.
class UserPolicy < ApplicationPolicy
  def atualizar_role?(novo_role)
    return false unless gestor?
    return false if user == record # escalada/lockout acidental

    envolve_gestao = User::ROLES_DE_GESTAO.include?(novo_role) || record.gestao?
    envolve_gestao ? user.presidencia? : true
  end
end
