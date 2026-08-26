# Espelho dos cargos no servidor do Discord (RF-EMB).
#
# O GET só LÊ e mostra o diff; o POST aplica. A separação existe porque apagar
# cargo no Discord é irreversível e tira de todo mundo na hora — a gestão vê o
# que vai acontecer antes de acontecer.
class Painel::DiscordController < Painel::BaseController
  def show
    @pendencias = PainelMetricas.new.pendencias
    @cargos = DiscordCargo.order(:nome)
    @configurado = DiscordSync.configurado?
    @plano = carregar_plano if @configurado
  end

  def sincronizar
    authorize Emblema, :update?
    # apagar é opt-in: vem de um botão próprio, nunca do "Aplicar" comum
    resultado = DiscordSync.aplicar!(apagar: params[:apagar] == "1")

    voltar_para painel_discord_path, resumo(resultado)
  rescue DiscordSync::NaoConfigurado, DiscordRest::ErroPermanente, RuntimeError => e
    redirect_to painel_discord_path, status: :see_other, alert: mensagem_do_erro(e)
  end

  private

  # O rescue envolve SÓ a chamada ao Discord. Envolvendo a action inteira, uma
  # falha aqui deixava @cargos sem atribuir e a view estourava em `nil.any?` —
  # o erro de rede virava erro de template, escondendo a causa.
  def carregar_plano
    DiscordSync.plano
  rescue DiscordSync::NaoConfigurado, DiscordRest::ErroPermanente, RuntimeError => e
    @erro = mensagem_do_erro(e)
    nil
  end

  def resumo(resultado)
    partes = [
      ("#{resultado[:criados]} criado(s)" if resultado[:criados].positive?),
      ("#{resultado[:atualizados]} atualizado(s)" if resultado[:atualizados].positive?),
      ("#{resultado[:apagados]} apagado(s)" if resultado[:apagados].positive?)
    ].compact

    partes.any? ? "Cargos sincronizados: #{partes.join(', ')}." : "Nada a fazer — já estava tudo em dia."
  end

  # 403 quase sempre é hierarquia, e é o erro que mais aparece: a mensagem
  # aponta o caminho em vez de deixar o gestor adivinhando.
  def mensagem_do_erro(erro)
    Rails.logger.warn("[discord] sync do painel: #{erro.message}")
    return "O Discord recusou (403). O cargo do bot precisa estar ACIMA dos cargos que ele " \
           "gerencia — ver docs/discord-bot.md." if erro.message.include?("403")

    "Não deu para falar com o Discord: #{erro.message}"
  end
end
