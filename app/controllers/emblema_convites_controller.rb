# Resgate do link exclusivo (RF-EMB): GET /e/:token.
#
# authenticate_user! faz todo o trabalho do caminho deslogado: o Devise guarda
# esta URL no stored_location e devolve o visitante para cá depois do login OU
# do cadastro — o que cobre e-mail/senha, Google e Discord sem hook nenhum.
# Quem já tem conta simplesmente reivindica.
#
# Rate limit por IP em config/initializers/rack_attack.rb: é GET, mas escreve,
# e o token é o único segredo.
class EmblemaConvitesController < ApplicationController
  include RecursoAtivo

  before_action :authenticate_user!
  exige_recurso "emblemas_ativos"

  def show
    convite = EmblemaConvite.includes(:emblema).find_by(token: params[:token])
    return redirect_to root_path, alert: "Link de emblema inválido." if convite.nil?

    if (recusa = convite.motivo_da_recusa)
      return redirect_to emblemas_path, alert: recusa
    end

    conceder(convite)
  end

  private

  # A vaga é reservada ANTES de conceder: o teto de resgates é a promessa do
  # link ("os 10 primeiros"), então o banco decide quem entra. Se a concessão
  # não render nada (já tinha o emblema único), a vaga volta — senão um clique
  # repetido queimaria a vaga de outra pessoa.
  def conceder(convite)
    emblema = convite.emblema
    return recusar(convite) unless convite.reservar_vaga!

    registro = emblema.conceder!(current_user, origem: "convite", convite: convite,
                                              descricao: convite.descricao)
    if registro
      redirect_to emblemas_path, notice: mensagem(emblema, registro)
    else
      EmblemaConvite.where(id: convite.id).update_all("usos = usos - 1")
      redirect_to emblemas_path, notice: "Você já tem o emblema “#{emblema.nome}”."
    end
  end

  def recusar(convite)
    redirect_to emblemas_path, alert: convite.reload.motivo_da_recusa || "Este link não está mais disponível."
  end

  def mensagem(emblema, registro)
    return "Emblema “#{emblema.nome}” desbloqueado!" unless emblema.escalonavel?

    nivel = registro.reload.nivel
    "“#{emblema.nome}” registrado#{" — agora #{nivel.nome}!" if nivel}"
  end
end
