# Papel de acesso "jornalista" (RF-NOV-04): escreve NOTÍCIA, como o "escritor"
# escreve BLOG. Nenhum dos dois é gestão — quem aprova continua sendo
# diretoria/presidência (User::ROLES_DE_GESTAO não muda).
#
# role é varchar + CHECK (não enum do Postgres), então o valor novo entra
# recriando a constraint. O nome e a ordem espelham devise_create_users.
class PapelJornalista < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :users,
      "role IN ('comunidade','escritor','parceiro','membro','diretoria','presidencia')",
      name: "users_role_check"

    add_check_constraint :users,
      "role IN ('comunidade','escritor','jornalista','parceiro','membro','diretoria','presidencia')",
      name: "users_role_check"
  end
end
