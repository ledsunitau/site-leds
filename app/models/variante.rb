# Variante do produto (tamanho, cor...). No modo estoque é ela que carrega a
# disponibilidade. No modo sob demanda o estoque não é consultado (quem manda é
# a quantidade_alvo do produto) — mas o valor FICA: zerar na troca de modo
# perderia o inventário, e RN-09 diz que a troca é reversível.
# Auditada junto com o produto (RN-13: "sempre auditados").
class Variante < ApplicationRecord
  has_paper_trail

  belongs_to :produto

  # "" não é NULL: o índice único é parcial (WHERE sku IS NOT NULL), então dois
  # SKUs vazios furariam o allow_blank da validação e estourariam RecordNotUnique
  # (500) no banco. Normalizar para nil alinha a validação com o índice.
  normalizes :sku, with: ->(sku) { sku.presence }

  validates :nome, presence: true
  validates :estoque, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_nil: true
  # peso (kg) e dimensões (cm) para a cotação de frete (RF-LOJ-11). Opcionais no
  # geral (sob demanda / retirada não usam); exigidos só na hora do envio.
  validates :peso, :altura, :largura, :comprimento,
            numericality: { greater_than: 0 }, allow_nil: true

  def dimensoes_para_frete? = [ peso, altura, largura, comprimento ].all?(&:present?)

  def card_json
    { id: id, nome: nome, sku: sku, estoque: estoque }
  end
end
