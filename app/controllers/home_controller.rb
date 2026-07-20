# Raiz pública: landing da LEDS. Números e destaques vêm do banco (RF-INI-01/02/07);
# com o banco vazio caem em zero / estado "nada por enquanto".
class HomeController < ApplicationController
  def index
    publicadas = Acao.publicadas.group(:detalhe_type).count
    @metricas = {
      membros: Member.count,
      projetos: publicadas["Projeto"] || 0,
      eventos: publicadas["Evento"] || 0
    }
    # Ações: as 3 mais recentes publicadas.
    @acoes = Acao.publicadas.includes(:detalhe, thumbnail_attachment: :blob)
                 .order(created_at: :desc).limit(3)
    # Novidades: as 6 publicações mais recentes (notícias E blog — a seção é
    # "Notícias & blog"). Na view, as 3 primeiras viram cards com foto
    # (destaque) e as 3 seguintes viram linhas de texto.
    @posts = Post.publicados.includes(thumbnail_attachment: :blob)
                 .order(published_at: :desc).limit(6)
    # Rede de membros (RF-INI-06/RF-GRA): grafo da gestão vigente, montado a
    # partir dos mandatos reais. Sem gestão/mandatos, a seção mostra vazio.
    gestao = Gestao.vigente
    @grafo = gestao && MembrosGrafo.grafo(gestao)
  end
end
