# Página da comunidade: arte + convite pro Discord. Exige login — assim o
# "Participe da comunidade" (home) só chega aqui após o usuário estar logado;
# deslogado, o Devise guarda a location e devolve pra cá depois do login.
class ComunidadeController < ApplicationController
  before_action :authenticate_user!

  DISCORD_INVITE = "https://discord.gg/jAnSTEXaqk".freeze

  def show
    @discord_invite = DISCORD_INVITE
    @membros = Member.count
  end
end
