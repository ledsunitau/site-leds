# Configurações da loja controladas pela gestão. Key/value simples com helpers
# tipados para as duas flags de hoje — NÃO é um framework de settings (ponytail:
# 2 flags; se virar muitas, aí sim generaliza). Auditado (PaperTrail) porque
# ligar/desligar a loja e trocar o modo de pagamento são atos de gestão.
class Setting < ApplicationRecord
  has_paper_trail

  validates :chave, presence: true, uniqueness: true

  MODOS_PAGAMENTO = %w[direto mercado_pago].freeze

  class << self
    # Loja ligada por padrão: sem linha no banco, a loja está no ar.
    def loja_ativa?
      ler("loja_ativa") != "false"
    end

    def loja_ativa=(valor)
      gravar("loja_ativa", valor ? "true" : "false")
    end

    # direto = intenção de compra (gestão fecha por contato); mercado_pago = gateway.
    def modo_pagamento
      valor = ler("modo_pagamento")
      MODOS_PAGAMENTO.include?(valor) ? valor : "direto"
    end

    def modo_pagamento=(valor)
      gravar("modo_pagamento", valor.to_s)
    end

    private

    def ler(chave)
      find_by(chave: chave)&.valor
    end

    def gravar(chave, valor)
      find_or_initialize_by(chave: chave).update!(valor: valor)
    end
  end
end
