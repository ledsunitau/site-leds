# Amplia os tipos de ideia (RF-IDE): além de projeto/pesquisa, a comunidade
# também sugere evento e palestra (desvio consciente do modelo original — o
# portal de ideias agrupa eventos/palestras e projetos/pesquisas).
class AddTiposDeIdeia < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :ideias, name: "ideias_tipo_check"
    add_check_constraint :ideias,
                         "tipo IN ('projeto','pesquisa','evento','palestra')",
                         name: "ideias_tipo_check"
  end

  def down
    remove_check_constraint :ideias, name: "ideias_tipo_check"
    add_check_constraint :ideias,
                         "tipo IN ('projeto','pesquisa')",
                         name: "ideias_tipo_check"
  end
end
