# Avaliação de produto (#LOJA4): estrelas (1..5) + comentário. Conteúdo do
# usuário — NÃO editável pela gestão. Só quem comprou avalia, e no máximo uma
# vez por produto (validação amigável + índice parcial único no banco).
class Avaliacao < ApplicationRecord
  belongs_to :produto
  belongs_to :autor, class_name: "User", foreign_key: :user_id,
                     optional: true, inverse_of: false

  validates :nota, numericality: { only_integer: true }, inclusion: { in: 1..5 }
  validates :comentario, length: { maximum: 2000 }
  validate :so_quem_comprou, on: :create
  validate :nao_avaliar_duas_vezes, on: :create

  scope :recentes, -> { order(created_at: :desc) }

  def card_json
    {
      id: id,
      nota: nota,
      comentario: comentario,
      autor: autor&.name,
      criado_em: created_at
    }
  end

  private

  # Confiança: só avalia quem tem pedido pago-ou-além com este produto.
  def so_quem_comprou
    return if produto.nil? || autor.nil?
    return if produto.comprado_por?(autor)

    errors.add(:base, "Só quem comprou este produto pode avaliá-lo.")
  end

  # Espelha Denuncia#nao_denunciar_duas_vezes: mensagem em pt-BR (o índice
  # parcial único é o backstop da corrida). Anônimas (user_id nil) convivem.
  def nao_avaliar_duas_vezes
    return if user_id.nil?
    return unless Avaliacao.exists?(user_id: user_id, produto_id: produto_id)

    errors.add(:base, "Você já avaliou este produto.")
  end
end
