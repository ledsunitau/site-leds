# RF-EMB: elo que usa as cores do PRÓPRIO SVG — o mesmo escape que o emblema
# ganhou em 20260827120000, agora no degrau.
#
# O ícone do elo era sempre repintado com a `cor` do elo, então qualquer arte
# com paleta própria virava um borrão de uma cor só. A cor continua valendo para
# o resto (ranking, nome do degrau, brilho dos efeitos); com esta coluna ligada,
# só o desenho para de ser repintado.
#
# Aditiva, com default: elo existente segue no comportamento antigo.
class EloSvgOriginal < ActiveRecord::Migration[8.1]
  def change
    add_column :elos, :svg_original, :boolean, null: false, default: false
  end
end
