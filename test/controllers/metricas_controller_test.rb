require "test_helper"

class MetricasControllerTest < ActionDispatch::IntegrationTest
  test "métricas públicas da landing contam só o publicado (RF-INI-01)" do
    get metricas_path

    assert_response :success
    body = response.parsed_body
    assert_equal 5, body["membros"]
    assert_equal 1, body["projetos"], "rascunho (acao_bot) fica de fora"
    assert_equal 1, body["eventos"]
    assert_equal 1, body["artigos"]
    assert_equal 2, body["noticias"]
    assert_equal 0, body["parceiros"], "tabela chega na F2"
  end
end
