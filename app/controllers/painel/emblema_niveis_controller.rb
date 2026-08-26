# Degraus de um emblema escalonável (RF-EMB): "o rank Ouro começa em 4".
# Vivem dentro da ficha do emblema, como os convites.
#
# Mexer num limiar pode subir ou descer o rank de quem já tem o emblema, então
# salvar reavalia os vínculos deste emblema na hora — e a varredura acerta os
# pontos e o elo de quem mudou.
class Painel::EmblemaNiveisController < Painel::BaseController
  before_action :carregar_emblema

  def create
    authorize @emblema, :update?
    @emblema.niveis.create!(nivel_params)

    reavaliar
    voltar_para edit_painel_emblema_path(@emblema), "Nível adicionado."
  end

  def destroy
    authorize @emblema, :update?
    @emblema.niveis.find(params[:id]).destroy!

    reavaliar
    voltar_para edit_painel_emblema_path(@emblema), "Nível removido."
  end

  private

  def carregar_emblema
    @emblema = Emblema.find(params[:emblema_id])
  end

  def nivel_params
    params.expect(emblema_nivel: [ :rank_id, :limiar, :discord_sincronizar ])
  end

  # Reaplica o rank de quem tem este emblema com os limiares novos. Escopo
  # pequeno de propósito (só os donos deste emblema); os pontos e o elo saem no
  # aplicar_nivel! de cada um.
  def reavaliar
    @emblema.reload.emblema_usuarios.includes(:user).find_each do |vinculo|
      progresso = @emblema.por_registro? ? vinculo.conquistas_count : @emblema.progresso_de(vinculo.user)
      vinculo.aplicar_nivel!(@emblema.nivel_para(progresso))
    end
  end
end
