# Card do membro (RF-MEM): skills (reusa Tecnologia + ícones do repo) e links
# de redes. E-mail já vem do user; discord já existe. bio/descrição já existe.
class MembrosSkillsERedes < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :github_url, :string
    add_column :members, :linkedin_url, :string
    add_column :members, :lattes_url, :string

    # Skills = tecnologias que o membro domina. Junção simples (sem PaperTrail:
    # não é dado auditável de gestão, é perfil do próprio membro).
    create_table :member_tecnologias do |t|
      t.references :member, null: false, foreign_key: { on_delete: :cascade }
      t.references :tecnologia, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :member_tecnologias, %i[member_id tecnologia_id], unique: true
  end
end
