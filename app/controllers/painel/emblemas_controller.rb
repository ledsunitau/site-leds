# Emblemas pela gestão (RF-EMB): cadastro completo da aparência (SVG, cor,
# efeito), da forma de aquisição (critério + meta) e do cargo do Discord.
#
# A ficha de EDIÇÃO concentra o resto — donos, concessão a dedo e os links
# exclusivos — no mesmo espírito de "variantes dentro do produto": criar
# redireciona para lá em vez de voltar para a listagem.
class Painel::EmblemasController < Painel::BaseController
  POR_PAGINA = 40

  before_action :carregar_emblema, only: %i[edit update destroy conceder revogar]

  def index
    @pendencias = PainelMetricas.new.pendencias
    @busca = filtro(:busca)

    escopo = Emblema.ordenados.includes(:produto, :niveis)
    if @busca
      escopo = escopo.where(Emblema.arel_table[:nome].matches("%#{Emblema.sanitize_sql_like(@busca)}%"))
    end

    @emblemas = paginar(escopo, por_pagina: POR_PAGINA)
    @total = Emblema.count
    @total_usuarios = Emblema.total_usuarios
  end

  def new
    @emblema = Emblema.new(cor: "#00C55B", efeito: "nenhum", ativo: true,
                           tipo: "unico", peso: 1, icone_svg: SVG_EXEMPLO)
    carregar_opcoes
  end

  def edit
    carregar_opcoes
    carregar_ficha
  end

  def create
    @emblema = Emblema.new(emblema_params)
    authorize @emblema
    @emblema.save!

    voltar_para edit_painel_emblema_path(@emblema), "“#{@emblema.nome}” cadastrado."
  end

  def update
    authorize @emblema
    @emblema.update!(emblema_params)

    voltar_para edit_painel_emblema_path(@emblema), "“#{@emblema.nome}” atualizado."
  end

  # Só enquanto ninguém tem (EmblemaPolicy#destroy?): apagar emblema com dono
  # apagaria conquista de gente. Para tirar de circulação existe `ativo: false`.
  def destroy
    authorize @emblema
    nome = @emblema.nome
    @emblema.destroy!

    voltar_para painel_emblemas_path, "“#{nome}” removido."
  end

  # Concessão a dedo (RF-EMB): a gestão escolhe a conta pelo e-mail e descreve o
  # que está registrando ("Maratona SBC 2026"), com data — que pode ser
  # retroativa, para lançar evento antigo.
  def conceder
    authorize @emblema, :conceder?
    usuario = User.find_by(email: params[:email].to_s.strip)
    return recusar("Nenhuma conta com esse e-mail.") if usuario.nil?

    registro = @emblema.conceder!(usuario, origem: "concessao", por: current_user.member,
                                           descricao: params[:descricao].presence,
                                           ocorrido_em: params[:ocorrido_em].presence)
    if registro
      voltar_para edit_painel_emblema_path(@emblema),
                  "“#{@emblema.nome}” registrado para #{usuario.name}."
    elsif @emblema.lotado?
      recusar("“#{@emblema.nome}” atingiu o teto de #{@emblema.limite_donos} donos.")
    else
      recusar("#{usuario.name} já tem este emblema.")
    end
  end

  def revogar
    authorize @emblema, :revogar?
    usuario = User.find(params[:user_id])
    @emblema.revogar!(usuario)

    voltar_para edit_painel_emblema_path(@emblema), "“#{@emblema.nome}” removido de #{usuario.name}."
  end

  private

  # Ícone de partida para a tela de cadastro: um SVG mínimo com
  # fill="currentColor", que é o formato que a cor e os efeitos esperam.
  SVG_EXEMPLO = <<~SVG.freeze
    <svg viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.3 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z"/>
    </svg>
  SVG

  def carregar_emblema
    @emblema = Emblema.find(params[:id])
  end

  def carregar_opcoes
    @ranks = EmblemaRank.ordenados
    @produtos = Produto.order(:nome)
  end

  def carregar_ficha
    @donos = @emblema.emblema_usuarios.recentes
                     .includes(:user, { nivel: :rank }, { conquistas: :concedido_por })
    @convites = @emblema.convites.recentes.includes(:criado_por)
    @niveis = @emblema.niveis.ordenados.includes(:rank)
  end

  def recusar(aviso)
    redirect_to edit_painel_emblema_path(@emblema), alert: aviso, status: :see_other
  end

  def emblema_params
    params.expect(emblema: [ :nome, :descricao, :icone_svg, :cor, :efeito,
                             :criterio, :meta, :exclusivo, :discord_role_id, :ativo,
                             :tipo, :peso, :limite_donos, :produto_id ])
          .tap do |limpos|
            # select vazio = "sem critério"/"sem produto": sem isto, "" cairia na
            # validação de inclusão em vez de virar "só de concessão"
            limpos[:criterio] = limpos[:criterio].presence
            limpos[:produto_id] = limpos[:produto_id].presence
            limpos[:limite_donos] = limpos[:limite_donos].presence
            # escalonável não usa meta — o limiar mora em cada rank
            limpos[:meta] = limpos[:tipo] == "escalonavel" ? nil : limpos[:meta].presence
          end
  end
end
