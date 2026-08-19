# Avaliações de produto (#LOJA4). Conteúdo do usuário: a gestão NÃO edita nota
# nem texto — só acompanha e, no abuso, remove. Comentário ganhou moderação com
# soft delete (RF-NOV-10) e avaliação não ganhou nada; sem esta tela, tirar uma
# avaliação ofensiva do ar exige console.
#
# destroy é destrutivo de verdade (não há coluna de status em avaliacoes) — por
# isso só remoção, sem "ocultar".
class Painel::AvaliacoesController < Painel::BaseController
  POR_PAGINA = 40

  def index
    @pendencias = PainelMetricas.new.pendencias
    @nota = filtro(:nota)

    escopo = Avaliacao.includes(:autor, :produto).recentes
    escopo = escopo.where(nota: @nota) if @nota

    @avaliacoes = paginar(escopo, por_pagina: POR_PAGINA)
    @por_nota = Avaliacao.group(:nota).count
    @media = Avaliacao.average(:nota)&.round(2)
  end

  def destroy
    avaliacao = Avaliacao.find(params[:id])
    avaliacao.destroy!
    voltar_para painel_avaliacoes_path, "Avaliação removida."
  end
end
