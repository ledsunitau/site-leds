# Descrição pessoal do usuário, editável no "Meu perfil" (RF-AUT-06). Distinta
# do Member.bio (institucional, curado pela gestão na página pública de Membros).
class AddBioToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :bio, :text
  end
end
