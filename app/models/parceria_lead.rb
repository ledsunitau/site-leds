# Lead do formulário público de parceria (RF-PAR-03). Cai no dashboard da
# gestão (RF-PAR-04); quando aceito, CONVERTE num Parceiro (preenche
# parceiro_id) — mantém "interessado" e "parceiro efetivo" distintos.
# A conversão passa por converter!, nunca por atribuição direta de status.
class ParceriaLead < ApplicationRecord
  # noticed usa record polimórfico SEM FK: o lead É destruído (eliminação LGPD
  # no admin), então sem esta limpeza sobra notificação órfã — e o pedido de
  # eliminação não teria levado tudo junto. Mesmo motivo do Post/Denuncia.
  has_many :noticed_events, as: :record, dependent: :destroy,
                            class_name: "Noticed::Event", inverse_of: :record

  belongs_to :parceiro, optional: true

  TIPOS = %w[software pesquisa evento patrocinio_geral].freeze
  STATUSES = %w[novo em_analise convertido recusado].freeze
  ABERTOS = %w[novo em_analise].freeze # únicos que ainda podem ser triados
  enum :tipo, TIPOS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo: o bang do enum pularia o parceiro da conversão
  private(*STATUSES.map { |s| :"#{s}!" })

  # Fronteira pública SEM login: teto de tamanho e formato entram aqui, senão
  # o throttle (que conta requests, não bytes) deixa passar um POST gigante.
  validates :empresa, :contato_email, presence: true
  validates :empresa, :contato_nome, length: { maximum: 200 }
  validates :contato_email, length: { maximum: 200 },
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :descricao, length: { maximum: 5_000 }

  # lead novo → avisa a gestão para triar (RF-PAR-04)
  after_create_commit :notificar_gestao, if: :novo?

  # Aceita o lead: cria o parceiro (vitrine) e amarra os dois.
  # NÃO copia a descricao do lead: aquele texto foi escrito para a liga ler
  # ("fale conosco", pode ter dado pessoal), não para virar vitrine pública —
  # a bio pública a gestão escreve depois, deliberadamente (RF-PAR-05/LGPD).
  def converter!
    transicionar!("convertido") do
      self.parceiro = Parceiro.create!(nome: empresa)
    end
    parceiro
  end

  def recusar!
    transicionar!("recusado")
  end

  private

  # with_lock: relê a linha antes de checar, então dois cliques não geram dois
  # parceiros — o segundo cai no guard e vira 422.
  def transicionar!(para)
    with_lock do
      unless ABERTOS.include?(status)
        errors.add(:status, "só lead novo ou em análise pode ser #{para}")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      yield if block_given?
      self.status = para
      save!
    end
  end

  def notificar_gestao
    gestores = User.gestao.to_a
    ParceriaLeadNotifier.with(record: self).deliver(gestores) if gestores.any?
  end
end
