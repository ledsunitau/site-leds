# Diretorias (RF-ADM-03). Renomear é seguro; apagar não é.
class Painel::DiretoriasController < Painel::BaseController
  def create
    Diretoria.create!(params.expect(diretoria: [ :nome ]))
    voltar_para painel_estrutura_path, "Diretoria criada."
  end

  def update
    diretoria = Diretoria.find(params[:id])
    diretoria.update!(params.expect(diretoria: [ :nome ]))
    voltar_para painel_estrutura_path, "Diretoria renomeada."
  end

  # A associação é `dependent: :nullify`, o que aqui seria uma armadilha: o
  # nullify é um UPDATE direto, sem validação, então diretor/membro ficariam
  # com diretoria_id nulo — estado que a RN-05 proíbe e que só apareceria
  # depois, ao editar o mandato. Por isso só apaga diretoria sem mandato.
  def destroy
    diretoria = Diretoria.find(params[:id])

    if diretoria.mandatos.exists?
      return redirect_to painel_estrutura_path, status: :see_other,
                         alert: "“#{diretoria.nome}” tem mandatos ligados a ela. Mova esses mandatos antes de apagar."
    end

    diretoria.destroy!
    voltar_para painel_estrutura_path, "Diretoria removida."
  end
end
