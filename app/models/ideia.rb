# Ideias propostas pela comunidade (RF-IDE, RN-01): qualquer usuário logado
# propõe; a gestão revisa (RF-IDE-04). Uma ideia aprovada pode virar no máximo
# UMA ação (RF-ACO-07 idealizador) — o vínculo é acoes.ideia_id. Revisão passa
# pela máquina de estados (aprovar!/rejeitar!), nunca por atribuição direta.
class Ideia < ApplicationRecord
  belongs_to :autor, class_name: "User", foreign_key: :user_id,
                     optional: true, inverse_of: :ideias
  belongs_to :revisor, class_name: "Member", foreign_key: :reviewed_by,
                       optional: true, inverse_of: false
  # a FK acoes.ideia_id é nullify: a ação sobrevive à ideia apagada
  has_one :acao, dependent: :nullify, inverse_of: :ideia

  TIPOS = %w[projeto pesquisa].freeze
  STATUSES = %w[pendente aprovada rejeitada].freeze
  enum :tipo, TIPOS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo: o bang do enum pularia revisor/reviewed_at
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :titulo, presence: true

  scope :pendentes, -> { pendente }

  # proposta nova → avisa a gestão para revisar (RF-IDE-04); revisão → avisa o autor.
  # after_UPDATE_commit na revisão: no create, saved_change_to_status? também é
  # true (nil→status), o que notificaria "aprovada" numa ideia criada já terminal
  # (seed/console) sem revisão nenhuma.
  after_create_commit :notificar_proposta, if: :pendente?
  after_update_commit :notificar_revisao, if: -> { saved_change_to_status? && (aprovada? || rejeitada?) }

  def aprovar!(revisor) = revisar!("aprovada", revisor)
  def rejeitar!(revisor) = revisar!("rejeitada", revisor)

  private

  # with_lock: duas revisões simultâneas passariam ambas no guard lido em
  # memória (notificação/estado em dobro); o lock relê a linha antes de checar.
  def revisar!(novo, revisor)
    with_lock do
      unless pendente?
        errors.add(:status, "só ideia pendente pode ser revisada")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      update!(status: novo, revisor: revisor, reviewed_at: Time.current)
    end
  end

  def notificar_proposta
    gestores = User.gestao.where.not(id: user_id).to_a
    IdeiaPropostaNotifier.with(record: self).deliver(gestores) if gestores.any?
  end

  def notificar_revisao
    IdeiaRevisadaNotifier.with(record: self, resultado: status).deliver(autor) if autor
  end
end
