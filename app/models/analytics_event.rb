# Evento de comportamento que abastece as métricas do admin (RF-ADM-02).
# Só coletado COM consentimento (RN-14) e gravado em lote pelo worker via
# insert_all — que pula validações/callbacks, então o controller monta linhas
# já limpas. Insert-only: nunca é editado (o DDL só tem created_at).
class AnalyticsEvent < ApplicationRecord
  belongs_to :user, optional: true

  validates :nome, presence: true
end
