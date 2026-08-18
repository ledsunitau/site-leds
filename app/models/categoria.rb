# Categoria de produto (RF-LOJ-01): agrupa a vitrine para o filtro do catálogo
# expandido (#LOJA2). Editável pela gestão no futuro (auditada como o resto).
class Categoria < ApplicationRecord
  has_paper_trail

  # produto.categoria_id vira NULL se a categoria some (on_delete: :nullify no DDL)
  has_many :produtos, dependent: :nullify

  validates :nome, presence: true, uniqueness: true

  # contagem exibida no filtro — só o que o cliente pode ver (ativos)
  def produtos_ativos_count = produtos.ativos.count
end
