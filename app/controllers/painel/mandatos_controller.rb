# Mandatos: cargo × diretoria × gestão de um membro (RF-ADM-03). Editados
# dentro da ficha do membro — mandato solto não significa nada.
#
# A coerência cargo×diretoria (RN-05: presidente/vice/orientador sem diretoria;
# diretor/membro com) mora no model e vale para qualquer caminho de escrita.
class Painel::MandatosController < Painel::BaseController
  def create
    mandato = Mandato.new(mandato_params)
    mandato.save!
    voltar_para edit_painel_membro_path(mandato.member_id), "Mandato adicionado."
  end

  def update
    mandato = Mandato.find(params[:id])
    mandato.update!(mandato_params)
    voltar_para edit_painel_membro_path(mandato.member_id), "Mandato atualizado."
  end

  def destroy
    mandato = Mandato.find(params[:id])
    membro_id = mandato.member_id
    mandato.destroy!
    voltar_para edit_painel_membro_path(membro_id), "Mandato removido."
  end

  private

  def mandato_params
    # diretoria_id vem "" quando o cargo não tem diretoria; sem o nil o
    # belongs_to optional receberia string vazia e a validação RN-05 acusaria
    # "não se aplica" num campo que a tela nem mostrou.
    params.expect(mandato: [ :member_id, :gestao_id, :cargo, :diretoria_id ])
          .tap { |p| p[:diretoria_id] = p[:diretoria_id].presence }
  end
end
