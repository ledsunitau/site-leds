# Endereço de entrega do usuário (RF-LOJ-04, envio). A tabela existe aqui pela
# FK do pedido; o CRUD e a validação de CEP/UF completa chegam com o fluxo de
# ENVIO (branch do frete). Por ora só o essencial para o pedido apontar.
class Endereco < ApplicationRecord
  belongs_to :user

  validates :cep, :logradouro, :cidade, :uf, presence: true
end
