# Dashboards detalhados (RF-ADM-02). Cinco recortes numa página com sub-abas:
# tráfego, conteúdo, loja, comunidade e LGPD.
#
# Janela opcional ?de=&ate= sobre cada domínio; as agregações vivem em
# PainelMetricas (cacheadas por janela).
class Painel::MetricasController < Painel::BaseController
  def show
    @pendencias = PainelMetricas.new.pendencias
    @de = data_do_filtro(:de)
    @ate = data_do_filtro(:ate)

    metricas = PainelMetricas.new(de: @de, ate: @ate)
    @trafego = metricas.trafego
    @conteudo = metricas.conteudo
    @loja = metricas.loja
    @comunidade = metricas.comunidade
    @lgpd = metricas.lgpd
  end
end
