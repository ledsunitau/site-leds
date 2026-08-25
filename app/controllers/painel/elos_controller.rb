# Degraus de elo (RF-EMB). Mesma forma do catálogo de ranks: uma tela com
# linhas editáveis, porque um elo é nome + cor + efeito + pontos + cargo.
#
# Mexer nos pontos mínimos remaneja a base inteira de degrau, então salvar
# reenfileira a varredura — deixar para a hora cheia mostraria gente no elo
# errado, e o elo é cargo no Discord.
class Painel::ElosController < Painel::BaseController
  before_action :carregar_elo, only: %i[update destroy]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @elos = Elo.ordenados
    @por_elo = User.where.not(elo_id: nil).group(:elo_id).count
    @elo = Elo.new(cor: "#00C55B", efeito: "nenhum", pontos_minimos: proximo_corte)
  end

  def create
    authorize Emblema, :create?
    Elo.create!(elo_params)

    EmblemasJob.perform_later
    voltar_para painel_elos_path, "Elo criado."
  end

  def update
    authorize Emblema, :update?
    @elo.update!(elo_params)

    EmblemasJob.perform_later
    voltar_para painel_elos_path, "“#{@elo.nome}” atualizado."
  end

  # A FK de users é nullify: quem estava neste elo fica sem elo até a varredura
  # recolocá-lo no degrau abaixo. Por isso o job é enfileirado aqui também.
  def destroy
    authorize Emblema, :update?
    nome = @elo.nome
    @elo.destroy!

    EmblemasJob.perform_later
    voltar_para painel_elos_path, "“#{nome}” removido."
  end

  private

  def carregar_elo
    @elo = Elo.find(params[:id])
  end

  # Sugestão para a linha em branco: o dobro do último corte, ou 10 no primeiro
  # elo. Só um chute útil — a gestão sobrescreve.
  def proximo_corte
    ultimo = Elo.maximum(:pontos_minimos)
    ultimo ? ultimo * 2 : 0
  end

  def elo_params
    params.expect(elo: [ :nome, :cor, :efeito, :icone_svg, :pontos_minimos, :discord_role_id ])
  end
end
