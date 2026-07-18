# Reserva do modo sob demanda (RF-LOJ-05/06, RN-10): sem pagamento, sem
# validade, cancelável. Só produto sob_demanda e ativo pode ser reservado
# (regra de negócio na aplicação, modelagem C9).
#
# RF-LOJ-07: quando as reservas ATIVAS de um produto atingem quantidade_alvo, o
# disparo de produção avisa os reservantes para pagar (DisparoProducaoJob). Quem
# paga tem a reserva CONVERTIDA num pedido (Checkout.da_reserva → Pedido#marcar_pago!).
class Reserva < ApplicationRecord
  include VarianteCoerente # variante tem de existir e ser DESTE produto

  belongs_to :user
  belongs_to :produto
  belongs_to :variante, optional: true
  belongs_to :pedido, optional: true # preenchido na conversão (sob demanda paga)

  STATUSES = %w[ativa cancelada convertida].freeze
  enum :status, STATUSES.index_by(&:itself), validate: true
  # transições só pelo fluxo (cancelar!/marcar_convertida!)
  private(*STATUSES.map { |s| :"#{s}!" })

  validates :quantidade, numericality: { greater_than: 0 }
  validate :produto_reservável, on: :create
  # uma reserva ATIVA por (usuário, produto, variante): reservar de novo é
  # ajustar quantidade, não empilhar linha (bounda o abuso e a demanda inflada).
  # App-level (o DDL não declara único) — janela de corrida vira duplicata, não dano.
  validate :sem_reserva_ativa_duplicada, on: :create

  # RF-LOJ-05/07: cruzou a meta agora → dispara a produção (avisa os reservantes
  # para pagar). Só no create que cruza a meta; creates seguintes com o total já
  # >= meta não re-notificam.
  after_create_commit :talvez_disparar_producao, if: :ativa?

  # RF-LOJ-06/RN-10: cancelável enquanto ativa (antes do disparo). O registro
  # fica (soft), vira 'cancelada' — histórico de demanda se preserva. with_lock
  # relê a linha: sem ele, cancelar! e a conversão (checkout) passariam ambos no
  # guard lido em memória e o cancelamento sobrescreveria uma reserva convertida.
  def cancelar!
    with_lock do
      unless ativa?
        errors.add(:status, "só reserva ativa pode ser cancelada")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      update!(status: "cancelada")
    end
  end

  # Pagamento aprovado do pedido converte a reserva (chamado por Pedido#marcar_pago!).
  # with_lock trava ESTA linha: sem ele, um cancelar! simultâneo (que trava a
  # reserva) e esta conversão passariam ambos no guard lido em memória e o último
  # UPDATE venceria — deixando reserva convertida cancelada, ou vice-versa.
  def marcar_convertida!
    with_lock do
      update!(status: "convertida") if ativa?
    end
  end

  def card_json
    {
      id: id,
      status: status,
      quantidade: quantidade,
      variante: variante&.card_json,
      produto: produto.card_json,
      criada_em: created_at
    }
  end

  private

  def talvez_disparar_producao
    meta = produto.quantidade_alvo
    return if meta.nil?

    # conta UNIDADES (uma reserva pode ser de várias), não linhas. Dispara só ao
    # CRUZAR a meta (esta reserva levou de <meta para >=meta); creates seguintes
    # com o total já >= meta não re-notificam. Lock serializa concorrentes.
    # ponytail: cruzamento simultâneo exato pode notificar 2x (raro); upgrade =
    # flag 'producao_disparada' persistida no produto.
    produto.with_lock do
      unidades = produto.reservas.ativa.sum(:quantidade)
      DisparoProducaoJob.perform_later(produto.id) if unidades >= meta && unidades - quantidade < meta
    end
  end

  def produto_reservável
    return if produto.nil?

    errors.add(:produto, "não está disponível") unless produto.ativo?
    errors.add(:produto, "não é sob demanda — não se reserva") unless produto.sob_demanda?
  end

  def sem_reserva_ativa_duplicada
    return unless ativa?

    duplicada = Reserva.ativa.where(user_id:, produto_id:, variante_id:).exists?
    errors.add(:base, "Você já tem uma reserva ativa deste produto.") if duplicada
  end
end
