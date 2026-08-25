# Catálogo de emblemas (RF-EMB) e equipamento do par destaque/secundário.
# Exige login: emblema é conquista de conta, não vitrine pública.
class EmblemasController < ApplicationController
  before_action :authenticate_user!

  TOPO = 50 # teto do ranking do elo final: uma tela, não uma listagem infinita

  # "Ver todos os emblemas": raridade, % de donos e como conseguir cada um.
  def index
    authorize Emblema
    # avalia na hora em vez de esperar o EmblemasJob da hora cheia — bater a
    # meta e não ver o emblema na tela que acabou de abrir seria confuso
    Emblema.avaliar!(current_user)

    @vinculos = EmblemaUsuario.where(user: current_user)
                              .includes(:conquistas, nivel: :rank).index_by(&:emblema_id)
    # Exclusivo é emblema-surpresa: fica fora do catálogo até o usuário ter.
    @emblemas = Emblema.ativos.ordenados.includes(niveis: :rank)
                       .reject { |e| e.exclusivo? && !@vinculos.key?(e.id) }
  end

  # A escada de elos + o top do elo mais alto. Login já é exigido no controller.
  def ranking
    authorize Emblema, :index?

    @elos = Elo.ordenados
    @por_elo = User.where.not(elo_id: nil).group(:elo_id).count
    @elo_final = Elo.final
    # o "top 1..N" existe só dentro do elo final — é o que faz o último degrau
    # valer a pena. ponytail: desempate por nome; não guardamos QUANDO cada um
    # chegou aos pontos, e inventar um proxy (idade da conta) seria pior.
    @topo = if @elo_final
      User.where(elo_id: @elo_final.id).includes(:emblema_destaque, foto_attachment: :blob)
          .order(pontos_emblemas: :desc, name: :asc).limit(TOPO)
    else
      User.none
    end
  end

  def equipar
    authorize Emblema, :index?
    # A validação de "só equipa o que é seu" mora no User (vale em todo caminho
    # de escrita); aqui só traduzimos o erro para o flash.
    if current_user.update(equipar_params)
      redirect_to profile_path(anchor: "emblemas"), notice: "Emblemas equipados."
    else
      redirect_to profile_path(anchor: "emblemas"), status: :see_other,
                  alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  def equipar_params
    # to_i converte "" em 0; presence antes disso mantém "desequipar" = nil
    params.expect(user: [ :emblema_destaque_id, :emblema_secundario_id ])
          .transform_values(&:presence)
  end
end
