# O vínculo "esta pessoa tem este emblema" — uma linha por (usuário, emblema),
# guardando o rank atual e quantos registros ela acumulou.
#
# O COMO e o QUANDO de cada cumprimento moram em emblema_conquistas: emblema
# único tem exatamente uma, escalonável acumula. Guardar origem/data aqui também
# seria um segundo lugar para a mesma verdade.
class EmblemaUsuario < ApplicationRecord
  # counter_cache: mantém emblemas.usuarios_count, de onde sai a raridade.
  belongs_to :emblema, counter_cache: :usuarios_count
  belongs_to :user
  # rank atual do emblema escalonável; nil em emblema único
  belongs_to :nivel, class_name: "EmblemaNivel", optional: true, inverse_of: :emblema_usuarios

  has_many :conquistas, class_name: "EmblemaConquista", dependent: :destroy,
                        inverse_of: :emblema_usuario

  validates :user_id, uniqueness: { scope: :emblema_id }

  # Perder o emblema desequipa. Sem isto, um destaque revogado continuaria
  # pintando o nome e o anel do avatar pelo site inteiro — a FK de users só
  # anula quando o EMBLEMA é apagado, não quando o vínculo some.
  #
  # No after_destroy (não no revogar! do Emblema) porque é o ponto por onde
  # TODA remoção passa: revogação da gestão, destroy_all e o cascade de
  # dependent: :destroy quando o emblema é excluído.
  after_destroy :desequipar

  scope :recentes, -> { order(created_at: :desc) }

  delegate :cor, :efeito, to: :nivel, allow_nil: true, prefix: true

  # A aparência efetiva: o rank manda quando existe (o mesmo maratonista, agora
  # em ouro); sem rank, vale a do emblema.
  def cor_efetiva = nivel_cor || emblema.cor
  def efeito_efetivo = nivel_efeito || emblema.efeito

  # Troca o rank e sincroniza o cargo do Discord (sai o antigo, entra o novo).
  # No-op quando o nível não mudou — evita enfileirar troca de cargo à toa a
  # cada varredura horária.
  def aplicar_nivel!(novo)
    return if nivel_id == novo&.id

    anterior = nivel
    update!(nivel: novo)
    DiscordCargoJob.perform_later(user_id, anterior.discord_role_id, "remover") if anterior&.discord_role_id.present?
    DiscordCargoJob.perform_later(user_id, novo.discord_role_id, "adicionar") if novo&.discord_role_id.present?
    user.recalcular_elo!
  end

  # Quanto falta para o próximo degrau, para a barra do card. nil quando já está
  # no rank mais alto ou o emblema não é escalonável.
  def proximo_nivel
    return nil unless emblema.escalonavel?

    emblema.niveis.ordenados.find_by("limiar > ?", nivel&.limiar.to_i)
  end

  private

  # update_all: escrita direta de duas colunas, sem recarregar nem revalidar o
  # usuário (a validação de "só equipa o que é seu" leria a linha que acabou de
  # sumir e reclamaria do estado que estamos justamente consertando).
  def desequipar
    User.where(id: user_id, emblema_destaque_id: emblema_id).update_all(emblema_destaque_id: nil)
    User.where(id: user_id, emblema_secundario_id: emblema_id).update_all(emblema_secundario_id: nil)
  end
end
