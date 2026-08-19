# Gestões / biênios (RF-ADM-03). Antes só existia `create`: uma gestão com o
# ano errado era permanente — e ela manda em Gestao.vigente, que decide o cargo
# exibido nos cards, no grafo e no geneograma.
class Painel::GestoesController < Painel::BaseController
  def create
    Gestao.create!(gestao_params)
    voltar_para painel_estrutura_path, "Gestão criada."
  end

  def update
    gestao = Gestao.find(params[:id])
    gestao.update!(gestao_params)
    voltar_para painel_estrutura_path, "Gestão atualizada."
  end

  # `dependent: :restrict_with_error` faz destroy! levantar RecordNotDestroyed
  # (não RecordInvalid), que o rescue_from da base não pega. Checar antes dá a
  # mensagem certa em vez de um 500.
  def destroy
    gestao = Gestao.find(params[:id])

    if gestao.mandatos.exists?
      return redirect_to painel_estrutura_path, status: :see_other,
                         alert: "A gestão #{gestao.ano_inicio}–#{gestao.ano_fim} tem mandatos. Remova-os antes de apagar."
    end

    gestao.destroy!
    voltar_para painel_estrutura_path, "Gestão removida."
  end

  private

  def gestao_params = params.expect(gestao: [ :ano_inicio, :ano_fim ])
end
