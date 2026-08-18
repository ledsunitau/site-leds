# Avaliação de produto (#LOJA4): estrelas (1..5) + comentário. Conteúdo do
# usuário — NÃO é editável pela gestão (ao contrário do resto da loja). Só quem
# comprou avalia (regra na aplicação) e no máximo uma vez por produto (índice
# parcial único, no estilo das denúncias).
class CreateAvaliacoes < ActiveRecord::Migration[8.1]
  def change
    create_table :avaliacoes do |t|
      t.references :produto, null: false, foreign_key: { on_delete: :cascade }
      # sobrevive à conta apagada (LGPD): a avaliação anonimiza, não some
      t.references :user, foreign_key: { on_delete: :nullify }
      t.integer :nota, null: false
      t.text :comentario
      t.timestamps
    end

    add_check_constraint :avaliacoes, "nota BETWEEN 1 AND 5", name: "avaliacoes_nota_check"
    # uma avaliação por (usuário, produto); anônimas (user_id NULL) convivem
    add_index :avaliacoes, %i[user_id produto_id], unique: true,
              where: "user_id IS NOT NULL", name: "index_avaliacoes_unicas_por_usuario"
  end
end
