# Visão geral do painel (RF-ADM-01/02): KPIs, o que precisa de atenção,
# tráfego e atividade recente. Uma tela, quatro faixas.
class Painel::DashboardController < Painel::BaseController
  ATIVIDADE = 12 # últimas mudanças auditadas mostradas na timeline

  def show
    @metricas = PainelMetricas.new
    @kpis = @metricas.kpis
    @pendencias = @metricas.pendencias
    @trafego = @metricas.trafego
    @atividade = atividade_recente
  end

  private

  # Timeline do PaperTrail. Sem a coluna `object` (snapshot inteiro, nunca lido
  # aqui) e ordenando por id: a tabela é insert-only, então o id segue o
  # created_at e o scan reverso sai pela PK. Mesmo critério do Admin::Audits.
  def atividade_recente
    versoes = PaperTrail::Version
                .select(:id, :item_type, :item_id, :event, :whodunnit, :created_at)
                .order(id: :desc)
                .limit(ATIVIDADE)
                .to_a

    autores = User.where(id: versoes.filter_map(&:whodunnit).uniq).index_by { |u| u.id.to_s }
    versoes.map { |v| [ v, autores[v.whodunnit] ] }
  end
end
