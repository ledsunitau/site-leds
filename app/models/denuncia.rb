# Denúncia de comentário (RF-NOV-09): alimenta a aba de denúncias do dashboard
# (RF-ADM-05). Resolver é ato da gestão e registra quem/quando — resolver NÃO
# modera o comentário: a gestão pode julgar improcedente. (O contrário SIM:
# moderar o comentário resolve as denúncias sobre ele — ver Comentario#moderar!.)
class Denuncia < ApplicationRecord
  # noticed usa record polimórfico SEM FK: a denúncia É destruída em cascata
  # (post → comentários → denúncias), então sem esta limpeza sobra notificação
  # órfã apontando para uma denúncia que não existe mais. Mesmo motivo do Post.
  has_many :noticed_events, as: :record, dependent: :destroy,
                            class_name: "Noticed::Event", inverse_of: :record

  belongs_to :comentario
  belongs_to :denunciante, class_name: "User", foreign_key: :user_id,
                           optional: true, inverse_of: :denuncias
  belongs_to :resolvedor, class_name: "Member", foreign_key: :resolved_by,
                          optional: true, inverse_of: false

  STATUSES = %w[pendente resolvida].freeze
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo: o bang do enum pularia resolvedor/resolved_at
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :motivo, length: { maximum: 500 }
  # Um denunciante não empilha denúncias no mesmo comentário (senão um clique
  # repetido vira N itens na aba). Validação própria em vez de `uniqueness:`
  # para a mensagem sair em prosa pt-BR — full_messages prefixaria o nome do
  # atributo ("User já está em uso") numa API que responde em português.
  # Respaldada por índice PARCIAL único (user_id, comentario_id) WHERE user_id
  # IS NOT NULL: a validação dá a mensagem amigável, o índice fecha a corrida de
  # POSTs concorrentes (RecordNotUnique → 422). Anonimizadas (user_id NULL) convivem.
  validate :nao_denunciar_duas_vezes, on: :create

  scope :pendentes, -> { pendente }

  # denúncia nova → avisa a gestão para triar (RF-ADM-05)
  after_create_commit :notificar_gestao, if: :pendente?

  # with_lock: dois gestores clicando resolver passariam ambos no guard lido em
  # memória, e o segundo sobrescreveria resolved_by (crédito errado no rastro).
  def resolver!(resolvedor)
    with_lock do
      unless pendente?
        errors.add(:status, "só denúncia pendente pode ser resolvida")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      update!(status: "resolvida", resolvedor: resolvedor, resolved_at: Time.current)
    end
  end

  private

  # user_id nil (autor apagou a conta — dependent: :nullify) não colide: duas
  # denúncias anonimizadas no mesmo comentário convivem legitimamente.
  def nao_denunciar_duas_vezes
    return if user_id.nil?

    return unless Denuncia.exists?(user_id: user_id, comentario_id: comentario_id)

    errors.add(:base, "Você já denunciou este comentário.")
  end

  def notificar_gestao
    gestores = User.gestao.to_a
    DenunciaNotifier.with(record: self).deliver(gestores) if gestores.any?
  end
end
