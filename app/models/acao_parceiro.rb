# Junção ação ↔ parceiro (RF-PAR-02). Auditada: mudar quem patrocina uma ação
# vira versão no PaperTrail (RNF-09) — por isso o diff-writer
# substitui_juncao_auditada, nunca delete_all.
class AcaoParceiro < ApplicationRecord
  has_paper_trail

  belongs_to :acao
  belongs_to :parceiro

  validates :parceiro_id, uniqueness: { scope: :acao_id }
end
