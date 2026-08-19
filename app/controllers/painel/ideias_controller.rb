# Ideias da comunidade (RF-IDE-04). A rota pública só tem `new`; a gestão não
# tinha onde ver o acervo — só o que estava pendente, pela fila de aprovações.
#
# Aqui também se fecha o vínculo idealizador (RF-ACO-07): uma ideia aprovada
# aponta para no máximo UMA ação, via acoes.ideia_id.
class Painel::IdeiasController < Painel::BaseController
  POR_PAGINA = 30

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)
    @tipo = filtro(:tipo)

    escopo = Ideia.includes(:autor, :revisor, :acao).order(created_at: :desc)
    escopo = escopo.where(status: @status) if @status
    escopo = escopo.where(tipo: @tipo) if @tipo

    @ideias = paginar(escopo, por_pagina: POR_PAGINA)
    @contagem = Ideia.group(:status).count
    @por_tipo = Ideia.group(:tipo).count
    # quantas já viraram ação: é o desfecho que a tela quer mostrar (RF-ACO-07)
    @viraram_acao = Acao.where.not(ideia_id: nil).count
  end

  def aprovar
    membro = member_atual
    return if membro.nil?

    ideia = Ideia.find(params[:id])
    ideia.aprovar!(membro)
    voltar_para painel_ideias_path, "Ideia “#{ideia.titulo}” aprovada."
  end

  def rejeitar
    membro = member_atual
    return if membro.nil?

    ideia = Ideia.find(params[:id])
    ideia.rejeitar!(membro)
    voltar_para painel_ideias_path, "Ideia “#{ideia.titulo}” rejeitada."
  end
end
# NÃO existe "vincular ideia a uma ação já criada": Acao valida
# `ideia_id_imutavel` (on: :update) — o idealizador é fixado no momento em que a
# ação nasce (RF-ACO-07) e não se re-aponta depois. A tela de ideias leva para
# "criar ação a partir desta ideia", que é o caminho que o model permite.
