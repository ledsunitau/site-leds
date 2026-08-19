require "test_helper"

# Sistema no painel: recursos (flags), limiares, métricas, logs, auditoria e LGPD.
# O ponto central é que uma flag desligada FECHA A ROTA — não só esconde o botão.
class PainelSistemaTest < ActionDispatch::IntegrationTest
  test "as telas de sistema exigem gestão" do
    sign_in users(:membro_user)

    [ painel_recursos_path, painel_metricas_path, painel_logs_path,
      painel_auditoria_path, painel_lgpd_path ].each do |rota|
      get rota
      assert_redirected_to root_path, "#{rota} deveria barrar papel comum"
    end
  end

  # ------------------------------------------------------------- Recursos

  test "recursos nascem ligados, menos manutenção" do
    assert Setting.ativo?("ideias_ativas")
    assert Setting.ativo?("loja_ativa")
    assert_not Setting.ativo?("manutencao"), "um deploy limpo não pode nascer em manutenção"
  end

  test "chave fora do registro é erro, não flag fantasma" do
    assert_raises(KeyError) { Setting.ativo?("recurso_que_nao_existe") }
  end

  test "desligar um recurso fecha a rota, não só o botão" do
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "ideias_ativas", ligado: "false" }
    assert_not Setting.ativo?("ideias_ativas")

    sign_in users(:ana)
    get new_ideia_path
    assert_response :see_other
    assert_match(/desativado/, flash[:alert])

    assert_no_difference -> { Ideia.count } do
      post ideias_path, params: { ideia: { tipo: "projeto", titulo: "x", descricao: "y" } }
    end
  end

  test "comentários desligados barram os novos e preservam os antigos" do
    existentes = Comentario.count
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "comentarios_ativos", ligado: "false" }

    sign_in users(:ana)
    post post_comentarios_path(posts(:noticia_publicada)), params: { comentario: { corpo: "oi" } }, as: :json
    assert_response :service_unavailable
    assert_equal existentes, Comentario.count, "os já publicados continuam no ar"
  end

  test "loja desligada fecha carrinho e reserva, não só o catálogo" do
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "loja_ativa", ligado: "false" }

    sign_in users(:ana)
    post carrinho_itens_path, params: { item: { produto_id: produtos(:camiseta).id, quantidade: 1 } }, as: :json
    assert_response :service_unavailable

    assert_no_difference -> { Reserva.count } do
      post reservas_path, params: { reserva: { produto_id: produtos(:moletom).id, quantidade: 1 } }, as: :json
    end
  end

  test "cadastro fechado barra e-mail e OAuth" do
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "cadastro_publico", ligado: "false" }
    sign_out users(:diretor)

    get new_user_registration_path
    assert_redirected_to new_user_session_path

    assert_no_difference -> { User.count } do
      post user_registration_path, params: { user: { name: "Novo", email: "novo@x.com", password: "senha-segura-123" } }
    end
  end

  test "modo manutenção fecha o site, mas não o login, o painel nem o webhook" do
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "manutencao", ligado: "true" }

    # gestão continua trabalhando
    get painel_path
    assert_response :success

    sign_in users(:ana)
    get root_path
    assert_response :service_unavailable

    sign_out users(:ana)
    get new_user_session_path
    assert_response :success, "sem login ninguém vira gestão para desfazer"

    # o gateway não repete a notificação para sempre
    post pagamentos_webhook_path, params: { type: "payment", data: { id: "1" } }, as: :json
    assert_not_equal 503, response.status, "o webhook não pode ser recusado em manutenção"
  end

  test "limiares de alerta são editáveis e persistem" do
    sign_in users(:diretor)
    assert_equal 5, Setting.limiar("alerta_denuncias")

    patch painel_recursos_limiares_path, params: { alerta_denuncias: "12" }
    assert_equal 12, Setting.limiar("alerta_denuncias")
  end

  test "toggle desconhecido é recusado" do
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "sudo", ligado: "true" }
    assert_match(/desconhecido/, flash[:alert])
  end

  # --------------------------------------------------------------- Alertas

  test "o job de alertas avisa a gestão quando o limiar estoura" do
    Denuncia.create!(comentario: comentarios(:visivel_na_noticia), denunciante: users(:ana), motivo: "spam")
    Setting.limiar!("alerta_denuncias", 0)

    assert_difference -> { Noticed::Event.where(type: "AlertaNotifier").count }, 1 do
      AlertasJob.perform_now
    end
  end

  test "uma checagem quebrada não derruba as outras nem vira loop de erro" do
    Setting.limiar!("alerta_denuncias", 0)
    Denuncia.create!(comentario: comentarios(:visivel_na_noticia), denunciante: users(:ana), motivo: "spam")

    job = AlertasJob.new
    job.define_singleton_method(:erros_recentes) { raise "banco fora do ar" }

    assert_nothing_raised { job.perform }
    assert Noticed::Event.where(type: "AlertaNotifier").exists?, "as demais checagens seguiram"
  end

  # ------------------------------------------------------- Logs e auditoria

  test "logs listam, filtram e mostram backtrace no detalhe" do
    log = ErrorLog.create!(occurred_at: 1.hour.ago, error_class: "RuntimeError",
                           error_message: "quebrou", rota: "POST /acoes", severidade: "error",
                           backtrace: "linha 1\nlinha 2", input_payload: { "a" => 1 })
    sign_in users(:diretor)

    get painel_logs_path
    assert_response :success
    assert_select "table.painel-table tbody tr", count: 1

    get painel_logs_path(severidade: "fatal")
    assert_select "table.painel-table tbody tr", count: 0

    get painel_log_path(log)
    assert_response :success
    assert_match "linha 2", response.body
  end

  test "auditoria mostra quem, o quê, onde e o diff" do
    sign_in users(:diretor)
    patch painel_recursos_path, params: { chave: "loja_ativa", ligado: "false" }

    get painel_auditoria_path(item_type: "Setting")
    assert_response :success
    assert_select ".painel-auditoria-item"
    assert_select ".painel-evento", minimum: 1, message: "o tipo de evento é rotulado"
    assert_select ".painel-auditoria-quem", minimum: 1, message: "quem fez aparece"
    assert_select ".painel-diff thead th", minimum: 1, message: "o diff tem cabeçalho antes/depois"
  end

  test "auditoria pagina sem contar a tabela inteira" do
    sign_in users(:diretor)
    # mais registros que o tamanho da página
    (Painel::AuditoriaController::POR_PAGINA + 2).times do |i|
      Categoria.create!(nome: "Cat #{i}")
    end

    get painel_auditoria_path(item_type: "Categoria")
    assert_select ".painel-auditoria-item", count: Painel::AuditoriaController::POR_PAGINA
    assert_select ".painel-paginacao a", text: /próxima/

    get painel_auditoria_path(item_type: "Categoria", pagina: 2)
    assert_select ".painel-auditoria-item", count: 2
    assert_select ".painel-paginacao a", text: /anterior/
  end

  # ------------------------------------------------------------------ LGPD

  test "eliminação apaga eventos e consentimento do titular" do
    CookieConsent.create!(user: users(:ana), anonymous_id: "abc123", analytics: true,
                          consented_at: Time.current)
    AnalyticsEvent.create!(user: users(:ana), anonymous_id: "abc123", nome: "pageview",
                           ocorrido_em: Time.current)
    sign_in users(:diretor)

    get painel_lgpd_path
    assert_response :success

    assert_difference -> { AnalyticsEvent.count }, -1 do
      delete painel_lgpd_path, params: { user_id: users(:ana).id }
    end
    assert_not CookieConsent.exists?(user: users(:ana))
  end

  test "eliminação sem titular é recusada" do
    sign_in users(:diretor)
    delete painel_lgpd_path
    assert_match(/Informe a conta/, flash[:alert])
  end

  test "métricas renderizam as cinco abas" do
    sign_in users(:diretor)
    get painel_metricas_path
    assert_response :success
    assert_select "[data-painel-target='panel']", count: 5
  end
end
