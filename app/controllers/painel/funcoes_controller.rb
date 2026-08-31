# Cadastro das funções (papéis) que uma pessoa exerce numa ação.
#
# Existe porque a lista era fechada no código: incluir "devops" ou "monitoria"
# exigia mexer em constante, enum e CHECK e subir deploy. Agora é dado.
#
# As junções guardam o papel por NOME (varchar), não por id — daí as regras:
#   - função PROTEGIDA não é renomeada nem apagada (organizador/participante
#     sustentam a divisão `organizadores`/`participantes` do JSON público);
#   - renomear qualquer outra reescreve as atribuições junto, na mesma transação;
#   - apagar exige zero usos, porque não há para onde mandar as linhas órfãs.
class Painel::FuncoesController < Painel::BaseController
  before_action :carregar_funcao, only: %i[update destroy]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @por_modalidade = Funcao.order(:nome).group_by(&:modalidade)
    @uso = { "projeto" => Contribuicao.group(:papel).count,
             "evento" => EventoMembro.group(:papel).count }
  end

  def create
    Funcao.create!(funcao_params)
    voltar_para painel_funcoes_path, "Função criada."
  end

  # Renomear leva as atribuições junto: as junções guardam o NOME, então mexer só
  # na tabela deixaria cada linha antiga apontando para um papel inexistente — e
  # elas parariam de validar na próxima edição da ação. Tudo numa transação
  # porque o estado intermediário (função com nome novo, linhas com o velho) é
  # exatamente o que a validação recusa.
  def update
    return recusar("“#{@funcao.nome}” é uma função do sistema e não pode ser renomeada.") if @funcao.protegida?

    antigo = @funcao.nome
    novo = params.require(:item)[:nome].to_s.strip

    Funcao.transaction do
      @funcao.update!(nome: novo)
      # Uma versão de PaperTrail por linha em vez de update_all: papel é campo
      # auditado (RNF-09) e o resto do app nunca usa delete_all/update_all nas
      # junções por essa razão.
      # ponytail: O(atribuições da função) numa ação rara de gestão. Se um dia
      # doer, o caminho é update_all + uma versão de resumo escrita à mão.
      juncao.where(papel: antigo).find_each { |linha| linha.update!(papel: novo) }
    end

    voltar_para painel_funcoes_path, "“#{antigo}” renomeada para “#{novo}”."
  end

  def destroy
    return recusar("“#{@funcao.nome}” é uma função do sistema e não pode ser apagada.") if @funcao.protegida?
    return recusar("“#{@funcao.nome}” está em uso em #{usos} registro(s).") if em_uso?

    @funcao.destroy!
    voltar_para painel_funcoes_path, "“#{@funcao.nome}” removida."
  end

  private

  def carregar_funcao
    @funcao = Funcao.find(params[:id])
  end

  # modalidade só entra na criação e sempre do conjunto fechado do model: mudar a
  # modalidade de uma função existente órfãnaria as linhas que já a usam.
  def funcao_params
    params.require(:item).permit(:nome, :modalidade)
          .tap { |p| p[:modalidade] = nil unless Funcao::MODALIDADES.include?(p[:modalidade]) }
  end

  def juncao = @funcao.modalidade == "projeto" ? Contribuicao : EventoMembro

  def usos = juncao.where(papel: @funcao.nome).count

  def em_uso? = usos.positive?

  def recusar(mensagem)
    redirect_to painel_funcoes_path, status: :see_other, alert: mensagem
  end
end
