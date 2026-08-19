# Painel de gestão (HTML). Portão único de /painel — diretoria e presidência.
#
# POR QUE existe separado de Admin::BaseController: /admin é a API JSON (contrato
# testado, Accept de browser nos testes de integração) e seus rescue_from são
# JSON-only. Servir HTML de lá quebraria os testes e despejaria JSON de erro na
# tela do gestor. Aqui a resposta é sempre HTML: gate redireciona, erro de
# validação re-renderiza o formulário.
#
# As actions de escrita NÃO reimplementam regra: chamam os métodos de model que
# já existem (post.aprovar!, pedido.marcar_enviado!, denuncia.resolver!...).
class Painel::BaseController < ApplicationController
  layout "painel"

  before_action :authenticate_user!
  before_action :exigir_gestao!

  # Erro de validação aqui é HTML, não JSON. O rescue_from do
  # ApplicationController responde `render_invalido` (corpo JSON) — contrato da
  # API, certo lá e ilegível aqui. Registrado depois, este ganha: no Rails o
  # último handler compatível é o que roda.
  rescue_from ActiveRecord::RecordInvalid do |e|
    redirect_back fallback_location: painel_path,
                  alert: e.record.errors.full_messages.to_sentence.presence || "Não foi possível salvar.",
                  status: :see_other
  end

  private

  def exigir_gestao!
    return if current_user.gestao?

    redirect_to root_path, alert: "Acesso restrito à gestão."
  end

  # Aprovar, moderar e resolver gravam autoria em members (Post#aprovar!,
  # Comentario#moderar!, Denuncia#resolver!, Ideia#aprovar!). Papel de gestão
  # pode existir sem perfil de membro — aí a ação não tem como registrar quem.
  def member_atual
    membro = current_user.member
    return membro if membro

    redirect_back fallback_location: painel_path, status: :see_other,
                  alert: "Sua conta ainda não tem perfil de membro — sem ele não dá para registrar quem revisou."
    nil
  end

  # 303 em toda escrita: o Turbo descarta resposta de formulário que não seja
  # redirect, e um 302 depois de DELETE reenviaria o método original.
  def voltar_para(destino, aviso)
    redirect_to destino, notice: aviso, status: :see_other
  end
end
