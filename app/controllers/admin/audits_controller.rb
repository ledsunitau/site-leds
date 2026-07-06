# RF-ADM-07: trilha de auditoria (PaperTrail) com diffs, filtrável por
# modelo, registro, usuário, evento e período.
class Admin::AuditsController < Admin::BaseController
  def index
    # sem a coluna object (snapshot completo, nunca lido aqui) — o diff é
    # object_changes; ordena por id (insert-only: id segue created_at e a
    # PK dá o scan reverso barato)
    versoes = PaperTrail::Version
                .select(:id, :item_type, :item_id, :event, :whodunnit, :created_at, :object_changes)
                .order(id: :desc)
    versoes = versoes.where(item_type: filtro(:item_type)) if filtro(:item_type)
    versoes = versoes.where(item_id: filtro(:item_id)) if filtro(:item_id)
    versoes = versoes.where(whodunnit: filtro(:user_id)) if filtro(:user_id)
    versoes = versoes.where(event: filtro(:evento)) if filtro(:evento)
    versoes = filtrar_por_periodo(versoes, :created_at)

    render json: { versoes: paginar(versoes, por_pagina: 50).map { |v| versao_json(v) } }
  end

  private

  def versao_json(versao)
    {
      id: versao.id,
      item_type: versao.item_type,
      item_id: versao.item_id,
      event: versao.event,
      whodunnit: versao.whodunnit,
      created_at: versao.created_at,
      mudancas: mudancas_da_versao(versao)
    }
  end
end
