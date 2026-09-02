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

  # Este GET escreve, e navegador nenhum sabe disso: o prefetch de hover do
  # Turbo, o prerender do Chrome e qualquer scanner de link resgatariam o
  # emblema sem ninguém ter clicado. Todos anunciam a intenção neste header.
  before_action :ignorar_prefetch
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

  def ignorar_prefetch
    proposito = "#{request.headers['X-Sec-Purpose']} #{request.headers['Sec-Purpose']}"
    head :no_content if proposito.include?("prefetch") || proposito.include?("prerender")
  end

  # ORDEM: quem já resgatou sai ANTES de mexer no contador. Se a checagem viesse
  # depois, um link esgotado responderia "as vagas acabaram" a quem só clicou de
  # novo no próprio resgate — e ainda daria um sobe-desce no contador a cada F5.
  #
  # Passada essa porta, a vaga é reservada ANTES de conceder: o teto é a promessa
  # do link ("os 10 primeiros"), então o banco decide quem entra. Se mesmo assim
  # a concessão não render nada, a vaga volta — senão um clique repetido queimaria
  # a vaga de outra pessoa.
  def conceder(convite)
    emblema = convite.emblema
    return ja_resgatou(convite) if convite.resgatado_por?(current_user)
    return recusar(convite) unless convite.reservar_vaga!

    registro = emblema.conceder!(current_user, origem: "convite", convite: convite,
                                              descricao: convite.descricao)
    if registro
      redirect_to emblemas_path, notice: mensagem(emblema, registro)
    else
      EmblemaConvite.where(id: convite.id).update_all("usos = usos - 1")
      redirect_to emblemas_path, **recusa_da_concessao(emblema)
    end
  end

  # Clique repetido no mesmo link. No emblema único isso é só "você já tem"; no
  # escalonável a pessoa PODE ganhar de novo, mas por outro link, e a mensagem
  # tem que ensinar isso — senão parece bug.
  def ja_resgatou(convite)
    emblema = convite.emblema
    aviso = if emblema.unico?
      "Você já tem o emblema “#{emblema.nome}”."
    else
      "Você já resgatou este link. Cada link vale uma vez — evento novo, link novo."
    end
    redirect_to emblemas_path, notice: aviso
  end

  # conceder! devolve nil por DOIS motivos (Emblema#registrar) e a mensagem tem
  # que dizer qual: ou a pessoa já tinha o emblema único, ou o teto de donos
  # fechou antes dela. Ter o vínculo separa os casos — quem não tem, não entrou.
  # Teto é recusa, então vai em alert; "você já tem" é só informação.
  def recusa_da_concessao(emblema)
    return { notice: "Você já tem o emblema “#{emblema.nome}”." } if emblema.emblema_usuarios.exists?(user: current_user)

    { alert: "O emblema “#{emblema.nome}” atingiu o teto de #{emblema.limite_donos} donos." }
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
