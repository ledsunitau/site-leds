# RF-INI-01: números da landing (contadores). Público e cacheado (RNF-01).
class MetricasController < ApplicationController
  def show
    payload = Rails.cache.fetch("metricas/landing", expires_in: 5.minutes) do
      publicadas = Acao.publicadas.group(:detalhe_type).count
      {
        membros: Member.count,
        projetos: publicadas["Projeto"] || 0,
        eventos: publicadas["Evento"] || 0,
        artigos: publicadas["Artigo"] || 0,
        noticias: Post.publicados.noticia.count,
        parceiros: 0 # tabela chega na F2 (feature/parceiros) — esperado
      }
    end

    render json: payload
  end
end
