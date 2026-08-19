# Diretorias e gestões numa tela só (RF-ADM-03). São dois CRUDs de dois campos
# cada e se leem juntos — a gestão vigente é o que dá sentido às diretorias no
# grafo e no geneograma. As ESCRITAS ficam em Painel::Diretorias/GestoesController.
class Painel::EstruturaController < Painel::BaseController
  def index
    @pendencias = PainelMetricas.new.pendencias
    @vigente = Gestao.vigente

    @diretorias = Diretoria.order(:nome)
    @gestoes = Gestao.order(ano_inicio: :desc)

    # quantos mandatos dependem de cada linha: é o que decide se dá para
    # apagar (gestões usam restrict_with_error; diretoria é bloqueada aqui)
    @mandatos_por_diretoria = Mandato.group(:diretoria_id).count
    @mandatos_por_gestao = Mandato.group(:gestao_id).count
  end
end
