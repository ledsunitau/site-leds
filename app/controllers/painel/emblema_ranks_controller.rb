# Catálogo de ranks (RF-EMB): bronze, prata, ouro, esmeralda, diamante, elite.
# Uma tela só, com linhas editáveis — no formato de Diretorias/Gestões
# (painel/estrutura), porque um rank é quatro campos, não uma ficha.
#
# Mexer em `peso` muda a pontuação de toda a base, então salvar reenfileira a
# varredura em vez de deixar o ranking mentindo até a hora cheia.
class Painel::EmblemaRanksController < Painel::BaseController
  before_action :carregar_rank, only: %i[update destroy]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @ranks = EmblemaRank.ordenados
    @rank = EmblemaRank.new(cor: "#CD7F32", efeito: "nenhum", peso: 1,
                            ordem: EmblemaRank.proxima_ordem)
  end

  def create
    authorize Emblema, :create?
    EmblemaRank.create!(rank_params)

    recalcular
    voltar_para painel_emblema_ranks_path, "Rank criado."
  end

  def update
    authorize Emblema, :update?
    @rank.update!(rank_params)

    recalcular
    voltar_para painel_emblema_ranks_path, "“#{@rank.nome}” atualizado."
  end

  # O rank é restrict no banco: se algum emblema o usa, a exclusão vira um erro
  # amigável em vez de 500 — tirar o "ouro" do catálogo apagaria o rank de quem
  # já o alcançou.
  def destroy
    # :update? (não :destroy?) porque EmblemaPolicy#destroy? consulta
    # record.usuarios_count — regra do emblema, que a classe não responde
    authorize Emblema, :update?
    if @rank.destroy
      voltar_para painel_emblema_ranks_path, "“#{@rank.nome}” removido."
    else
      redirect_to painel_emblema_ranks_path, status: :see_other,
                  alert: "“#{@rank.nome}” está em uso por algum emblema — remova o nível antes."
    end
  end

  private

  def carregar_rank
    @rank = EmblemaRank.find(params[:id])
  end

  def rank_params
    params.expect(emblema_rank: [ :nome, :cor, :efeito, :peso, :ordem ])
  end

  def recalcular
    EmblemasJob.perform_later
  end
end
