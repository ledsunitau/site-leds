# RF-ADM-03: cargos por gestão (mandatos). A coerência cargo × diretoria
# (RN-05) já mora no model.
class Admin::MandatosController < Admin::BaseController
  def create
    mandato = Mandato.create!(mandato_params)
    render json: mandato_json(mandato), status: :created
  end

  def update
    mandato = Mandato.find(params[:id])
    mandato.update!(mandato_params)
    render json: mandato_json(mandato)
  end

  def destroy
    mandato = Mandato.find(params[:id])
    mandato.destroy!
    head :no_content
  end

  private

  def mandato_params
    params.expect(mandato: [ :member_id, :gestao_id, :cargo, :diretoria_id ])
  end

  def mandato_json(mandato)
    {
      id: mandato.id,
      member_id: mandato.member_id,
      gestao_id: mandato.gestao_id,
      cargo: mandato.cargo,
      diretoria_id: mandato.diretoria_id
    }
  end
end
