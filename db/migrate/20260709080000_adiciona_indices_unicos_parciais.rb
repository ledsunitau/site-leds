# Fecha as duas janelas de corrida que eram só app-level (decisão do dono do
# schema, tomada na entrega do deploy): torna DB-authoritative o que a validação
# já garantia no caso comum. Índices PARCIAIS (nulos não colidem), no mesmo
# estilo de index_variantes_on_sku.
class AdicionaIndicesUnicosParciais < ActiveRecord::Migration[8.1]
  def up
    # RF-ACO-07: uma ideia vira no MÁXIMO uma ação. Troca o índice não-único por
    # parcial único (ideia_id NULL = ação sem idealizador, convivem).
    remove_index :acoes, name: "index_acoes_on_ideia_id"
    add_index :acoes, :ideia_id, unique: true, where: "ideia_id IS NOT NULL",
              name: "index_acoes_on_ideia_id"

    # RF-NOV-09: um denunciante não empilha denúncia no mesmo comentário.
    # Denúncias anonimizadas (user_id NULL, autor apagado) convivem — daí o WHERE.
    add_index :denuncias, %i[user_id comentario_id], unique: true,
              where: "user_id IS NOT NULL", name: "index_denuncias_unicas_por_denunciante"
  end

  def down
    remove_index :denuncias, name: "index_denuncias_unicas_por_denunciante"
    remove_index :acoes, name: "index_acoes_on_ideia_id"
    add_index :acoes, :ideia_id, name: "index_acoes_on_ideia_id"
  end
end
