# RF-ADM-02: agregações de analytics_events para o painel. Atrás do gate de
# gestão (Admin::BaseController). Janela opcional ?de=/&ate= (ISO) sobre
# ocorrido_em, reusando filtrar_por_periodo.
class Admin::MetricsController < Admin::BaseController
  # Teto de grupos: nome/rota vêm do payload público (texto livre). Sem limite,
  # eventos forjados com valores únicos explodiriam o JSON. Top-N por contagem.
  TOP = 50

  def show
    escopo = filtrar_por_periodo(AnalyticsEvent.all, :ocorrido_em)

    render json: {
      total: escopo.count,
      # visitantes ~ cookies únicos (definição padrão de web analytics); NULL fora
      visitantes_unicos: escopo.distinct.count(:anonymous_id),
      por_nome: escopo.group(:nome).order(Arel.sql("COUNT(*) DESC")).limit(TOP).count,
      por_rota: escopo.where.not(rota: nil).group(:rota).order(Arel.sql("COUNT(*) DESC")).limit(TOP).count,
      # dia LOCAL: ocorrido_em é gravado em UTC (AR default) mas o app opera em
      # America/Sao_Paulo — sem converter, tráfego noturno cai no dia seguinte.
      por_dia: escopo.group(Arel.sql("DATE((ocorrido_em AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')")).count
    }
  end
end
