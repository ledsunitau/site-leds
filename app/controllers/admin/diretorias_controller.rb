# RF-ADM-03: gestão das diretorias (criar/renomear; sem destroy — são
# entidades históricas referenciadas por mandatos).
class Admin::DiretoriasController < Admin::BaseController
  def create
    diretoria = Diretoria.create!(params.expect(diretoria: [ :nome ]))
    render json: diretoria_json(diretoria), status: :created
  end

  def update
    diretoria = Diretoria.find(params[:id])
    diretoria.update!(params.expect(diretoria: [ :nome ]))
    render json: diretoria_json(diretoria)
  end

  private

  def diretoria_json(diretoria)
    { id: diretoria.id, nome: diretoria.nome }
  end
end
