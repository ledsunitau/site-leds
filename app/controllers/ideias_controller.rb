# Ideias (RF-IDE): a comunidade propõe (RN-01), a gestão revisa (RF-IDE-04).
# index lista as ideias do próprio usuário (a fila da gestão vive em
# Admin::ApprovalsController). Throttle da proposta em rack_attack.rb.
class IdeiasController < ApplicationController
  include RecursoAtivo

  before_action :authenticate_user!
  # painel → Recursos: desligar Ideias fecha o formulário E a rota
  exige_recurso "ideias_ativas", only: %i[new create]

  def index
    authorize Ideia
    ideias = current_user.ideias.order(created_at: :desc)
    render json: { ideias: paginar(ideias).map { |i| ideia_json(i) } }
  end

  def show
    ideia = Ideia.find(params[:id])
    authorize ideia
    render json: ideia_json(ideia, completo: true)
  end

  # Portal de ideias (RF-IDE): o formulário. @grupo pré-filtra os tipos quando
  # vem dos botões da home (?grupo=eventos|projetos).
  def new
    authorize Ideia, :create?
    @ideia = current_user.ideias.new
    @grupo = params[:grupo].presence_in(Ideia::GRUPOS.keys)
  end

  def create
    authorize Ideia
    @ideia = current_user.ideias.new(ideia_params)
    if @ideia.save
      respond_to do |format|
        format.json { render json: ideia_json(@ideia, completo: true), status: :created }
        format.html { redirect_to new_ideia_path, notice: "Ideia enviada! A gestão vai revisar. 💡" }
      end
    else
      respond_to do |format|
        format.json { render_invalido(@ideia) }
        format.html { @grupo = nil; render :new, status: :unprocessable_entity }
      end
    end
  end

  def aprovar
    revisar(:aprovar!, :aprovar?)
  end

  def rejeitar
    revisar(:rejeitar!, :rejeitar?)
  end

  private

  def ideia_params
    params.expect(ideia: %i[tipo titulo descricao])
  end

  def revisar(metodo, permissao)
    ideia = Ideia.find(params[:id])
    authorize ideia, permissao

    revisor = exigir_member!
    return if revisor.nil?

    ideia.public_send(metodo, revisor)
    render json: ideia_json(ideia, completo: true)
  end

  def ideia_json(ideia, completo: false)
    json = {
      id: ideia.id,
      tipo: ideia.tipo,
      titulo: ideia.titulo,
      status: ideia.status,
      criada_em: ideia.created_at
    }
    if completo
      json[:descricao] = ideia.descricao
      json[:revisada_em] = ideia.reviewed_at
      json[:acao_id] = ideia.acao&.id # a ação que a ideia virou, se houver
    end
    json
  end
end
