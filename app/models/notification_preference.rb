# RF-NOT-06: preferência de entrega por (usuário × canal × categoria). Modelo
# OPT-OUT: sem linha explícita, o canal está ligado (DDL default true). Só os
# canais de SAÍDA (email/push/discord) são gateados por aqui — o in_app é o
# registro base do noticed, sempre gravado (o centro de notificações é a
# história completa). whatsapp é canal válido (DDL) sem entrega implementada.
class NotificationPreference < ApplicationRecord
  belongs_to :user

  CANAIS = %w[in_app email push discord whatsapp].freeze
  enum :canal, CANAIS.index_by(&:itself), validate: true

  # Só estes têm entrega de saída controlável e são gateados por habilitado?.
  # in_app é sempre gravado (o centro é o histórico completo); whatsapp ainda
  # não tem entrega. Aceitar preferência para eles seria um ajuste que não faz
  # nada — então o create rejeita, em vez de mentir um 201 inócuo (RF-NOT-06).
  CANAIS_CONFIGURAVEIS = %w[email push discord].freeze
  validates :canal, inclusion: { in: CANAIS_CONFIGURAVEIS }

  # Categorias reais (= CATEGORIA dos notifiers). Lista fechada: barra texto
  # livre (criação ilimitada) e o no-op silencioso de "moderação" ≠ "moderacao".
  # Cada branch nova que adiciona um notifier registra sua categoria aqui.
  CATEGORIAS = %w[moderacao publicacao ideias].freeze
  validates :categoria, inclusion: { in: CATEGORIAS }
  validates :canal, uniqueness: { scope: %i[user_id categoria] }

  def self.habilitado?(user:, canal:, categoria:)
    pref = find_by(user: user, canal: canal, categoria: categoria)
    pref.nil? || pref.enabled
  end
end
