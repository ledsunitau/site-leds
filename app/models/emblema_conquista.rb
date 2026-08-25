# Um cumprimento do emblema. Emblema único tem exatamente uma; escalonável
# acumula (é a contagem que faz subir de rank quando o emblema não usa métrica).
#
# É o que o hover do perfil lista — "Maratona SBC 2026 · 14 mai 2026" — e é
# aqui que mora a data de aquisição, não em emblema_usuarios.
class EmblemaConquista < ApplicationRecord
  belongs_to :emblema_usuario, counter_cache: :conquistas_count
  belongs_to :convite, class_name: "EmblemaConvite", optional: true, inverse_of: :conquistas
  belongs_to :concedido_por, class_name: "Member", optional: true, inverse_of: false
  belongs_to :pedido, optional: true, inverse_of: false

  ORIGENS = %w[meta concessao convite compra].freeze
  ORIGEM_LABEL = {
    "meta" => "Conquistou", "concessao" => "Concedido",
    "convite" => "Link exclusivo", "compra" => "Compra"
  }.freeze

  validates :origem, inclusion: { in: ORIGENS }
  validates :descricao, length: { maximum: 160 }

  # ocorrido_em pode ser retroativo (registrar a maratona do ano passado), mas
  # nunca futuro — data à frente furaria qualquer regra de exclusividade por data.
  validate :nao_pode_ser_no_futuro

  before_validation { self.ocorrido_em ||= Time.current }

  scope :recentes, -> { order(ocorrido_em: :desc) }

  def origem_label = ORIGEM_LABEL[origem]

  # O texto do hover. Sem descrição cai na origem — "Concedido", "Compra".
  def resumo = descricao.presence || origem_label

  private

  def nao_pode_ser_no_futuro
    return if ocorrido_em.blank? || ocorrido_em <= Time.current

    errors.add(:ocorrido_em, "não pode estar no futuro")
  end
end
