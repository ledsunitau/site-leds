# Resultado da moderação do post (RF-NOV-05): avisa o autor que seu post foi
# publicado ou rejeitado. record = o Post; params[:resultado] = status final.
class PostModeradoNotifier < ApplicationNotifier
  CATEGORIA = "publicacao"

  required_param :resultado

  def titulo
    publicado? ? "Seu post foi publicado" : "Seu post foi rejeitado"
  end

  def mensagem
    acao = publicado? ? "publicado" : "rejeitado"
    "\"#{record&.titulo}\" foi #{acao}." # record& : post pode ter sido apagado
  end

  def url = (publicado? && record) ? "/posts/#{record.id}" : nil

  private

  def publicado? = params[:resultado].to_s == "publicado"
end
