require "test_helper"

# Smoke de todas as telas do painel. Os testes por fase cobrem comportamento;
# este cobre RENDERIZAÇÃO — uma view com helper errado ou local faltando só
# aparece quando a página é montada de verdade.
#
# As rotas são descobertas do router, então uma tela nova entra aqui sozinha:
# esquecer de testar deixa de ser possível.
class PainelSmokeTest < ActionDispatch::IntegrationTest
  # Rotas com :id são exercidas nos testes de fase (precisam de um registro
  # específico); aqui ficam as de listagem e formulário em branco.
  ROTAS_COM_ID = %w[
    /painel/logs/:id /painel/membros/:id/edit /painel/acoes/:id/edit
    /painel/posts/:id/edit /painel/posts/:id/versoes /painel/produtos/:id/edit
    /painel/parceiros/:id/edit /painel/emblemas/:id/edit
  ].freeze

  def rotas_get
    Rails.application.routes.routes.filter_map do |rota|
      caminho = rota.path.spec.to_s.sub("(.:format)", "")
      next unless caminho.start_with?("/painel")
      next unless rota.verb == "GET"
      next if caminho.include?(":") # cobertas nos testes de fase

      caminho
    end.uniq
  end

  test "toda tela de listagem do painel renderiza para a gestão" do
    sign_in users(:diretor)

    rotas = rotas_get
    assert rotas.size >= 15, "esperava o painel inteiro, achei só #{rotas.size} rotas"

    rotas.each do |caminho|
      get caminho
      assert_response :success, "#{caminho} não renderizou (#{response.status})"
    end
  end

  test "as telas com id renderizam" do
    sign_in users(:diretor)

    log = ErrorLog.create!(occurred_at: 1.hour.ago, error_class: "E", error_message: "m",
                           severidade: "error", backtrace: "b")

    [
      painel_log_path(log),
      edit_painel_membro_path(members(:membro_comum)),
      edit_painel_acao_path(acoes(:acao_site)),
      edit_painel_acao_path(acoes(:acao_hackathon)),
      edit_painel_acao_path(acoes(:acao_artigo)),
      edit_painel_post_path(posts(:noticia_publicada)),
      versoes_painel_post_path(posts(:noticia_publicada)),
      edit_painel_produto_path(produtos(:camiseta)),
      edit_painel_parceiro_path(parceiros(:tech_corp)),
      # os três lados da ficha de emblema: com links de convite, com donos e o
      # escalonável (que mostra a tabela de ranks)
      edit_painel_emblema_path(emblemas(:convidado_beta)),
      edit_painel_emblema_path(emblemas(:fundador_honorario)),
      edit_painel_emblema_path(emblemas(:maratonista)),
      new_painel_membro_path,
      new_painel_produto_path,
      new_painel_parceiro_path,
      new_painel_acao_path(tipo: "projeto"),
      new_painel_acao_path(tipo: "evento"),
      new_painel_acao_path(tipo: "artigo"),
      new_painel_post_path
    ].each do |caminho|
      get caminho
      assert_response :success, "#{caminho} não renderizou (#{response.status})"
    end
  end

  test "o painel inteiro fica fora do alcance de quem não é gestão" do
    sign_in users(:ana)

    rotas_get.each do |caminho|
      get caminho
      assert_redirected_to root_path, "#{caminho} deveria barrar papel comum"
    end
  end

  test "o editor de texto rico está servido no layout do painel" do
    sign_in users(:diretor)
    get new_painel_post_path

    assert_select "trix-editor", count: 1
    assert_match "trix", response.body, "o CSS do Trix precisa estar no layout"
  end
end
