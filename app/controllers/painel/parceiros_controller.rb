# Parceiros (RF-PAR-01/02/05). A rota pública só cria e edita; não havia index
# de gestão nem destroy — tirar um parceiro do banco (eliminação LGPD, registro
# duplicado) exigia console.
class Painel::ParceirosController < Painel::BaseController
  before_action :carregar_parceiro, only: %i[edit update destroy]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @status = filtro(:status)

    escopo = Parceiro.includes(:conta, logo_attachment: :blob).order(:nome)
    escopo = escopo.where(status: @status) if @status

    @parceiros = escopo.to_a
    @acoes_por_parceiro = AcaoParceiro.group(:parceiro_id).count
    @por_status = Parceiro.group(:status).count
  end

  def new
    @parceiro = Parceiro.new(status: "ativo")
    carregar_opcoes
  end

  def edit
    carregar_opcoes
  end

  def create
    @parceiro = Parceiro.new(parceiro_params)
    authorize @parceiro
    @parceiro.save!
    voltar_para painel_parceiros_path, "“#{@parceiro.nome}” cadastrado."
  end

  def update
    authorize @parceiro
    @parceiro.update!(parceiro_params)
    voltar_para painel_parceiros_path, "“#{@parceiro.nome}” atualizado."
  end

  # LGPD art. 18 + registro duplicado. A junção acao_parceiros vai junto
  # (dependent: :destroy), mas os leads convertidos sobrevivem (FK nullify),
  # preservando o histórico de como a parceria nasceu.
  def destroy
    authorize @parceiro, :gerenciar?
    nome = @parceiro.nome
    @parceiro.destroy!
    voltar_para painel_parceiros_path, "“#{nome}” removido. As ações apoiadas continuam, sem a marca."
  end

  private

  def carregar_parceiro
    @parceiro = Parceiro.find(params[:id])
  end

  # Contas ainda sem parceiro (parceiros.user_id é único na aplicação) mais a
  # conta já vinculada a este, senão o select viria vazio na edição.
  def carregar_opcoes
    vinculadas = Parceiro.where.not(id: @parceiro.id).where.not(user_id: nil).select(:user_id)
    @contas = User.where.not(id: vinculadas).order(:name)
  end

  def parceiro_params
    params.expect(parceiro: [ :nome, :site_url, :status, :depoimento, :user_id, :logo ])
  end
end
