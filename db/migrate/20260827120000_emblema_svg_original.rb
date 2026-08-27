# RF-EMB: emblema que usa as cores do PRÓPRIO SVG.
#
# Até aqui o desenho era sempre repintado com a cor única do emblema
# (`.emblema svg :not([fill="none"]) { fill: currentColor }`). Isso é o certo
# para ícone de traço simples — troca a cor por rank sem redesenhar —, mas
# destrói qualquer arte com gradiente ou paleta própria: todas as formas viram
# a mesma cor chapada e a maior cobre as outras.
#
# Com a coluna ligada, o CSS não repinta e o SVG sai como foi colado. Os efeitos
# (brilho, neon, arco-íris, pulso) continuam valendo — eles são filtro/transform
# sobre o conjunto, não dependem de repintar forma por forma.
#
# Aditiva, com default: emblema existente continua no comportamento antigo sem
# precisar de backfill.
class EmblemaSvgOriginal < ActiveRecord::Migration[8.1]
  def change
    add_column :emblemas, :svg_original, :boolean, null: false, default: false
  end
end
