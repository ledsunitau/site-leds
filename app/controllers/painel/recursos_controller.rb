# Ativação de recursos e limiares de alerta (painel → Recursos / Alertas).
# Tudo escreve em Setting, que é auditado — quem desligou a loja e quando fica
# na trilha do PaperTrail.
class Painel::RecursosController < Painel::BaseController
  def index
    @pendencias = PainelMetricas.new.pendencias
    @flags = Setting::FLAGS
    @limiares = Setting::LIMIARES
    @modo_pagamento = Setting.modo_pagamento
    # quem mexeu por último em cada configuração
    @ultimas = PaperTrail::Version.where(item_type: "Setting").order(id: :desc).limit(10)
    @autores = User.where(id: @ultimas.filter_map(&:whodunnit).uniq).index_by { |u| u.id.to_s }
  end

  # Um toggle por vez: o formulário manda a chave e o novo valor. Trocar tudo
  # de uma vez num só submit geraria uma versão de auditoria por request, não
  # por decisão — e a leitura da trilha é justamente "quem desligou o quê".
  def update
    chave = params.require(:chave).to_s

    unless Setting::FLAGS.key?(chave)
      return redirect_to painel_recursos_path, status: :see_other, alert: "Recurso desconhecido."
    end

    ligado = params[:ligado] == "true"
    Setting.ativar!(chave, ligado)

    voltar_para painel_recursos_path,
                "#{Setting::FLAGS.fetch(chave)[:label]} #{ligado ? 'ligado' : 'desligado'}."
  end

  def modo_pagamento
    modo = params.require(:modo_pagamento).to_s

    unless Setting::MODOS_PAGAMENTO.include?(modo)
      return redirect_to painel_recursos_path, status: :see_other, alert: "Modo de pagamento desconhecido."
    end

    Setting.modo_pagamento = modo
    voltar_para painel_recursos_path, "Modo de pagamento: #{modo.humanize}."
  end

  def limiares
    Setting::LIMIARES.each_key do |chave|
      valor = params[chave]
      next if valor.blank?

      Setting.limiar!(chave, valor)
    end

    voltar_para painel_recursos_path, "Limiares de alerta atualizados."
  end
end
