# Comentário em post (RF-NOV-08). Nasce visivel — publicado na hora, sem fila.
# A gestão oculta/remove (RF-NOV-10) via moderar!, que é SOFT DELETE: a linha
# fica, o rastro se preserva (quem moderou e quando). Comentários são planos
# (sem threads); para respostas no futuro, basta um parent_id (modelagem C5).
class Comentario < ApplicationRecord
  has_paper_trail # RF-ADM-07: moderar comentário é ato de gestão, fica auditado

  belongs_to :post
  belongs_to :autor, class_name: "User", foreign_key: :user_id,
                     optional: true, inverse_of: :comentarios
  belongs_to :moderador, class_name: "Member", foreign_key: :moderated_by,
                         optional: true, inverse_of: false
  has_many :denuncias, dependent: :destroy

  # STATUSES está em ordem de ESCALADA: moderar só anda para frente.
  STATUSES = %w[visivel oculto removido].freeze
  MODERADOS = %w[oculto removido].freeze # os estados que a gestão pode aplicar
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo: o bang do enum pularia moderador/moderated_at
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :corpo, presence: true, length: { maximum: 5_000 }
  # No model, não no controller: a regra vale em TODO caminho de escrita
  # (console, seed, admin futuro) — mesmo motivo do Post#retornar_para_aprovacao.
  # on: :create — moderar! precisa seguir funcionando se o post sair do ar depois.
  validate :post_deve_estar_no_ar, on: :create

  scope :visiveis, -> { visivel }

  # RF-NOV-10: tirar do ar preserva o registro. Só AVANÇA (visivel → oculto →
  # removido): voltar para visivel não é previsto, e rebaixar removido→oculto
  # sobrescreveria moderated_by/at, apagando quem de fato removeu.
  # with_lock porque o guard lê estado persistido (duas moderações simultâneas
  # passariam ambas no guard lido em memória).
  def moderar!(novo_status, moderador)
    with_lock do
      unless escalada?(novo_status)
        errors.add(:status, "moderação só avança para oculto ou removido")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      update!(status: novo_status, moderador: moderador, moderated_at: Time.current)
      # tirar o comentário do ar É a resolução das denúncias sobre ele: sem
      # isto a aba (RF-ADM-05) fica cheia de pendências já resolvidas na prática
      denuncias.pendentes.each { |d| d.resolver!(moderador) }
    end
  end

  # Forma única do comentário na API (aqui e na aba de denúncias): mascarar ou
  # truncar o corpo um dia vale nos dois lugares.
  def card_json
    {
      id: id,
      corpo: corpo,
      status: status,
      autor: autor && { id: autor.id, name: autor.name },
      criado_em: created_at
    }
  end

  private

  def escalada?(novo_status)
    MODERADOS.include?(novo_status) &&
      STATUSES.index(novo_status) > STATUSES.index(status)
  end

  def post_deve_estar_no_ar
    errors.add(:post, "precisa estar publicado para receber comentários") unless post&.publicado?
  end
end
