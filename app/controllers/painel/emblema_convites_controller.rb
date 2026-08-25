# Links exclusivos de um emblema (RF-EMB), gerenciados dentro da ficha do
# emblema. O token nasce no model (has_secure_token) — a gestão só escolhe o
# prazo e liga/desliga.
class Painel::EmblemaConvitesController < Painel::BaseController
  before_action :carregar_emblema

  def create
    authorize @emblema, :update?
    @emblema.convites.create!(expira_em: params[:expira_em].presence,
                              usos_max: params[:usos_max].presence,
                              descricao: params[:descricao].presence,
                              criado_por: current_user.member)

    voltar_para edit_painel_emblema_path(@emblema), "Link gerado."
  end

  # Liga/desliga o link. Só `ativo` muda aqui: prazo, vagas e descrição são a
  # promessa feita a quem recebeu o link — reabrir vagas depois de esgotar seria
  # mudar a regra no meio, e para isso a gestão gera outro link.
  def update
    authorize @emblema, :update?
    convite = @emblema.convites.find(params[:id])
    convite.update!(ativo: params[:ativo] == "1")

    voltar_para edit_painel_emblema_path(@emblema), "Link atualizado."
  end

  def destroy
    authorize @emblema, :update?
    @emblema.convites.find(params[:id]).destroy!

    voltar_para edit_painel_emblema_path(@emblema), "Link removido."
  end

  private

  def carregar_emblema
    @emblema = Emblema.find(params[:emblema_id])
  end
end
