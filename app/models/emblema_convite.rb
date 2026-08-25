# Link exclusivo de um emblema (RF-EMB): quem abre /e/:token logado ganha o
# emblema; deslogado, o Devise manda logar/cadastrar e devolve para cá.
#
# Três controles independentes na mão da gestão: `ativo` (liga/desliga na hora),
# `expira_em` (prazo; NULL = sem prazo) e `usos_max` (vagas; NULL = ilimitado —
# é o "os 10 primeiros que resgatarem"). Um link recusado continua na tela, com
# o histórico de usos.
#
# `descricao` é o que vira o texto do registro no emblema escalonável
# ("Maratona SBC 2026") e aparece no hover do perfil.
class EmblemaConvite < ApplicationRecord
  belongs_to :emblema
  belongs_to :criado_por, class_name: "Member", optional: true, inverse_of: false
  has_many :conquistas, class_name: "EmblemaConquista", foreign_key: :convite_id,
                        dependent: :nullify, inverse_of: :convite

  # 32 hex: não enumerável e ainda cabe numa URL que dá para mandar no chat.
  has_secure_token :token, length: 32

  validates :token, uniqueness: true
  validates :descricao, length: { maximum: 160 }
  validates :usos_max, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :recentes, -> { order(created_at: :desc) }

  def valido? = ativo? && !expirado? && !esgotado?

  def expirado? = expira_em.present? && expira_em.past?

  def esgotado? = usos_max.present? && usos >= usos_max

  def vagas_restantes = usos_max.present? ? [ usos_max - usos, 0 ].max : nil

  # Reserva uma vaga e devolve true se conseguiu. UM update condicional, não
  # "checa e depois incrementa": dez pessoas clicando junto num link de 10 vagas
  # passariam todas pela checagem antes de qualquer incremento, e onze entrariam.
  # O banco decide, e quem perder a corrida recebe 0 linhas afetadas.
  def reservar_vaga!
    self.class.where(id: id, ativo: true)
        .where("expira_em IS NULL OR expira_em > ?", Time.current)
        .where("usos_max IS NULL OR usos < usos_max")
        .update_all("usos = usos + 1")
        .positive?
  end

  # Motivo da recusa, para a mensagem do flash — "link inválido" seco esconde
  # que basta a gestão religar.
  def motivo_da_recusa
    return "Este link foi desativado." unless ativo?
    return "Este link expirou." if expirado?
    return "Este link já foi resgatado por todo mundo — as vagas acabaram." if esgotado?

    nil
  end
end
