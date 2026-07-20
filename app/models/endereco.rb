# Endereço de entrega do usuário (RF-LOJ-04, envio). Usado como destino da
# cotação e da etiqueta do Melhor Envio (RF-LOJ-11). Do próprio usuário.
class Endereco < ApplicationRecord
  belongs_to :user

  # CEP guardado só com dígitos (o Melhor Envio quer 8 dígitos); a coluna aceita
  # 9 chars para o formato com hífen, mas normalizamos para dígitos.
  normalizes :cep, with: ->(cep) { cep.to_s.gsub(/\D/, "").presence }
  normalizes :uf, with: ->(uf) { uf.to_s.strip.upcase.presence }

  validates :cep, presence: true, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }
  validates :logradouro, :cidade, presence: true
  validates :uf, presence: true, format: { with: /\A[A-Z]{2}\z/, message: "deve ser a sigla (2 letras)" }

  def card_json
    {
      id: id, cep: cep, logradouro: logradouro, numero: numero,
      complemento: complemento, bairro: bairro, cidade: cidade, uf: uf
    }
  end
end
