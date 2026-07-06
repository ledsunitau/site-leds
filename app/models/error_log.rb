# Log de erros da aplicação (RF-ADM-08/09, RNF-14). Insert-only: linhas
# nunca são editadas (o DDL nem tem updated_at). O input_payload chega
# MASCARADO de quem registra (RN-16) — nunca passar params crus.
class ErrorLog < ApplicationRecord
  LIMITE_BACKTRACE = 50

  belongs_to :user, optional: true

  SEVERIDADES = %w[info warning error fatal].freeze
  enum :severidade, SEVERIDADES.index_by(&:itself), validate: true

  # Registrar um erro NUNCA pode derrubar o request/job que já está
  # falhando: qualquer falha aqui vira log de texto e segue a vida.
  def self.registrar(excecao, contexto = {})
    create!(
      occurred_at: Time.current,
      ambiente: Rails.env,
      error_class: excecao.class.name,
      error_message: excecao.message,
      backtrace: excecao.backtrace&.first(LIMITE_BACKTRACE)&.join("\n"),
      **contexto
    )
  rescue StandardError => e
    Rails.logger.error("ErrorLog.registrar falhou: #{e.class}: #{e.message}")
    nil
  end
end
