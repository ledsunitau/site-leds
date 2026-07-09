# Resultado da revisão da ideia (RF-IDE-04): avisa o autor que sua ideia foi
# aprovada ou rejeitada. record = a Ideia; params[:resultado] = status final.
class IdeiaRevisadaNotifier < ApplicationNotifier
  CATEGORIA = "ideias"

  required_param :resultado

  def titulo
    aprovada? ? "Sua ideia foi aprovada" : "Sua ideia foi rejeitada"
  end

  def mensagem
    acao = aprovada? ? "aprovada" : "rejeitada"
    "\"#{record&.titulo}\" foi #{acao}."
  end

  private

  def aprovada? = params[:resultado].to_s == "aprovada"
end
