# Toggles da loja controlados pela gestão (RF-LOJ / painel admin). Herda o gate
# de gestão do Admin::BaseController. Liga/desliga a loja e alterna o modo de
# pagamento (direto ↔ mercado_pago).
class Admin::LojaConfigsController < Admin::BaseController
  def update
    Setting.loja_ativa = params[:loja_ativa] == "true" if params.key?(:loja_ativa)

    if Setting::MODOS_PAGAMENTO.include?(params[:modo_pagamento])
      Setting.modo_pagamento = params[:modo_pagamento]
    end

    redirect_back fallback_location: produtos_path, notice: "Configuração da loja atualizada."
  end
end
