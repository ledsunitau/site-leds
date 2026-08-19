# Catálogos reutilizáveis: tecnologias (stack dos projetos e skills dos
# membros), temas (classificação dos artigos) e congressos.
#
# Um controller para os três porque são a MESMA coisa — nome + ícone opcional —
# e três controllers idênticos só multiplicariam o lugar onde consertar. O tipo
# vem de um mapa fechado, nunca de constantize sobre params.
#
# Estado anterior: tecnologias e congressos eram create-only (um erro de
# digitação era permanente) e temas nem create tinha — só o seed. E o artigo
# valida de 1 a 3 temas, então esse catálogo é peça de operação, não enfeite.
class Painel::CatalogosController < Painel::BaseController
  TIPOS = {
    "tecnologias" => { classe: Tecnologia, rotulo: "Tecnologia", icone: true },
    "temas" => { classe: Tema, rotulo: "Tema", icone: true },
    "congressos" => { classe: Congresso, rotulo: "Congresso", icone: false }
  }.freeze

  before_action :carregar_tipo, except: :index

  def index
    @pendencias = PainelMetricas.new.pendencias
    @tecnologias = Tecnologia.with_attached_icone.order(:nome)
    @temas = Tema.with_attached_icone.order(:nome)
    @congressos = Congresso.order(:nome)

    @uso = {
      "tecnologias" => ProjetoTecnologia.group(:tecnologia_id).count,
      "temas" => ArtigoTema.group(:tema_id).count,
      "congressos" => Apresentacao.group(:congresso_id).count
    }
  end

  def create
    @config[:classe].create!(item_params)
    voltar_para painel_catalogos_path, "#{@config[:rotulo]} criado."
  end

  def update
    @config[:classe].find(params[:id]).update!(item_params)
    voltar_para painel_catalogos_path, "#{@config[:rotulo]} atualizado."
  end

  # Congresso usa restrict_with_error (apresentações apontam para ele), que faz
  # destroy! levantar RecordNotDestroyed — exceção que o rescue_from da base não
  # pega. Tecnologia/Tema têm dependent: :destroy nas junções, então apagar
  # remove a classificação dos projetos/artigos: por isso o aviso de uso.
  def destroy
    item = @config[:classe].find(params[:id])
    nome = item.nome

    unless item.destroy
      return redirect_to painel_catalogos_path, status: :see_other,
                         alert: "“#{nome}” não pode ser apagado: #{item.errors.full_messages.to_sentence}"
    end

    voltar_para painel_catalogos_path, "“#{nome}” removido."
  end

  private

  def carregar_tipo
    @config = TIPOS[params[:tipo]]
    return if @config

    redirect_to painel_catalogos_path, status: :see_other, alert: "Catálogo desconhecido."
  end

  def item_params
    permitidos = @config[:icone] ? %i[nome icone] : %i[nome]
    params.require(:item).permit(*permitidos)
  end
end
