# RF-EMB: um resgate por pessoa POR LINK de emblema.
#
# Emblema escalonável sobe de rank a cada registro, e a única guarda contra
# repetição em Emblema#registrar era `unico?`. Resultado: recarregar o mesmo link
# dava registro novo e rank novo — num link sem teto de vagas, rank infinito a
# golpe de F5. O escalonável PRECISA acumular (três maratonas, três registros),
# então a trava não pode ser por emblema: é por link, que é justamente como o
# schema já identificava o evento (EmblemaConvite#descricao vira o texto do
# registro no perfil). Evento novo, link novo.
#
# Parcial, aditiva e sem backfill: conquista fora de link (meta, concessão,
# compra) tem convite_id NULL e não é tocada. Confirmado no banco antes de
# escrever — nenhum par (convite_id, emblema_usuario_id) duplicado existe, então
# o índice sobe sem dedupe.
class UmResgatePorLink < ActiveRecord::Migration[8.1]
  def up
    # Troca o índice de coluna única pelo composto: convite_id é o prefixo dele,
    # então as buscas do dependent: :nullify e da FK ON DELETE SET NULL seguem
    # atendidas. Manter os dois custaria uma escrita a mais por conquista à toa.
    remove_index :emblema_conquistas, name: "index_emblema_conquistas_on_convite_id"
    add_index :emblema_conquistas, %i[convite_id emblema_usuario_id], unique: true,
              where: "convite_id IS NOT NULL", name: "index_conquistas_unicas_por_convite"
  end

  def down
    remove_index :emblema_conquistas, name: "index_conquistas_unicas_por_convite"
    add_index :emblema_conquistas, :convite_id, name: "index_emblema_conquistas_on_convite_id"
  end
end
