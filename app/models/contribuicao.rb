# Quem fez o quê no projeto (RF-ACO-03). Um membro pode ter mais de um papel
# no mesmo projeto (único por projeto+membro+papel).
class Contribuicao < ApplicationRecord
  has_paper_trail # RF-ADM-07: trocar quem contribuiu também é "o que mudou"

  belongs_to :projeto
  belongs_to :member

  # A lista vive na tabela `funcoes` (cadastrável pelo painel), não num enum:
  # papel novo não pode exigir deploy. Lambda porque `in:` é avaliado uma vez na
  # carga da classe — cadastrar uma função só valeria depois de reiniciar.
  validates :papel, inclusion: { in: ->(_) { Funcao.nomes_de("projeto") },
                                 message: "não é uma função cadastrada" }
  validates :papel, uniqueness: { scope: [ :projeto_id, :member_id ] }
end
