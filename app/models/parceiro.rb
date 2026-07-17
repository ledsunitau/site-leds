# Parceiro efetivo da liga (RF-PAR). Nasce da conversão de um lead aceito
# (ParceriaLead#converter!) ou direto pela gestão. A vitrine (RF-PAR-01) são os
# ativos; as ações de cada parceiro (RF-PAR-02) saem de acao_parceiros.
# user_id é opcional: o registro existe assim que aceito, mas a área própria
# (RF-PAR-05) só liga quando há conta vinculada.
class Parceiro < ApplicationRecord
  # RF-ADM-07: quem tirou um parceiro da vitrine (status), renomeou ou trocou a
  # conta vinculada tem que ficar registrado — a junção já era auditada, o
  # registro em si não era. (O ParceriaLead NÃO é auditado de propósito: as
  # versões copiariam o nome/e-mail do contato e sobreviveriam à eliminação
  # pedida via LGPD, que é justamente o que o destroy do lead existe para dar.)
  has_paper_trail

  belongs_to :conta, class_name: "User", foreign_key: :user_id,
                     optional: true, inverse_of: :parceiro

  has_many :acao_parceiros, dependent: :destroy
  has_many :acoes, through: :acao_parceiros
  # o lead sobrevive ao parceiro apagado (FK nullify), guardando o histórico
  has_many :parceria_leads, dependent: :nullify

  STATUSES = %w[ativo inativo].freeze
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :nome, presence: true
  # User has_one :parceiro, mas o índice do DDL em parceiros(user_id) é
  # NÃO-unique (o de members é unique) — sem isto, dois parceiros na mesma
  # conta fazem user.parceiro devolver um deles a esmo. App-level por
  # autoridade do DDL, mesma abordagem de Acao#ideia_id.
  validates :user_id, uniqueness: true, allow_nil: true
  # optional: true não checa existência: um user_id inexistente iria até o
  # banco e voltaria InvalidForeignKey (500), furando o contrato de 422
  validates :conta, presence: true, if: :user_id?

  scope :ativos, -> { ativo }

  def card_json
    { id: id, nome: nome, site_url: site_url, status: status }
  end
end
