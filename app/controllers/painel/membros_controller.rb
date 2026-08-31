# Perfis de membro (RF-ADM-03): vínculo com a conta, bio, foto, padrinho, a tag
# de fundador (RN-04) e as skills do card (member_tecnologias — que até aqui não
# tinham NENHUMA rota de escrita no app).
#
# Os mandatos do membro são editados na própria ficha (Painel::MandatosController).
class Painel::MembrosController < Painel::BaseController
  before_action :carregar_membro, only: %i[edit update destroy]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @gestao = Gestao.vigente
    @membros = Member.includes(:user, :padrinho, mandatos: %i[gestao diretoria])
                     .with_attached_foto
                     .order("users.name")
                     .references(:user)
  end

  def new
    @membro = Member.new
    carregar_opcoes
  end

  def edit
    carregar_opcoes
    @mandato = Mandato.new(member: @membro, gestao: Gestao.vigente)
  end

  def create
    @membro = Member.new(membro_params)
    authorize @membro
    @membro.save!
    voltar_para edit_painel_membro_path(@membro), "Perfil de #{@membro.name} criado — falta o mandato."
  end

  def update
    authorize @membro
    @membro.update!(membro_params)
    voltar_para painel_membros_path, "Perfil de #{@membro.name} atualizado."
  end

  def destroy
    authorize @membro
    nome = @membro.name
    @membro.destroy!
    voltar_para painel_membros_path, "Perfil de #{nome} removido. A conta do usuário continua existindo."
  end

  private

  def carregar_membro
    @membro = Member.find(params[:id])
  end

  # Contas ainda sem perfil (members.user_id é único) + a do próprio membro em
  # edição, senão o select viria vazio na tela de editar.
  def carregar_opcoes
    vinculadas = Member.where.not(id: @membro.id).select(:user_id)
    @contas = User.where.not(id: vinculadas).order(:name)
    @padrinhos = Member.includes(:user).where.not(id: @membro.id).order("users.name").references(:user)
    @tecnologias = Tecnologia.order(:nome)
  end

  def membro_params
    # tecnologia_ids: [""] no fim é o hidden do check_box_tag múltiplo — o
    # Rails filtra o vazio sozinho, e sem ele desmarcar tudo não enviaria a
    # chave e as skills antigas ficariam.
    params.expect(member: [ :user_id, :bio, :founder, :padrinho_id, :foto,
                            :github_url, :linkedin_url, :lattes_url, { tecnologia_ids: [] } ])
  end
end
