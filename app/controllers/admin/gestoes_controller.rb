# RF-ADM-03: abrir nova gestão (os mandatos apontam para ela; a "vigente"
# é derivada pelo resolver único Gestao.vigente).
class Admin::GestoesController < Admin::BaseController
  def create
    gestao = Gestao.create!(params.expect(gestao: [ :ano_inicio, :ano_fim ]))
    render json: { id: gestao.id, ano_inicio: gestao.ano_inicio, ano_fim: gestao.ano_fim },
           status: :created
  end
end
