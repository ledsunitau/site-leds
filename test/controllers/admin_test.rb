require "test_helper"

# Namespace /admin (RF-ADM): gate de gestão + cada painel.
class AdminTest < ActionDispatch::IntegrationTest
  test "gate: anônimo é mandado logar; sem gestão é 403; diretoria e presidência entram" do
    get admin_approvals_path
    assert_response :redirect

    sign_in users(:membro_user)
    get admin_approvals_path
    assert_response :forbidden

    sign_in users(:diretor)
    get admin_approvals_path
    assert_response :success

    sign_in users(:presidente_user)
    get admin_approvals_path
    assert_response :success
  end

  test "painel de jobs (/admin/jobs) fica atrás do mesmo gate" do
    sign_in users(:membro_user)
    get "/admin/jobs"
    assert_response :forbidden

    sign_in users(:diretor)
    get "/admin/jobs"
    assert_response :success
  end

  # --- error_logs (RF-ADM-08/09) ---

  test "error_logs filtra por severidade, rota, usuário e período" do
    sign_in users(:diretor)
    velho = ErrorLog.create!(occurred_at: 10.days.ago, error_class: "RuntimeError",
                             rota: "POST /acoes", severidade: "error", user: users(:ana))
    novo = ErrorLog.create!(occurred_at: 1.hour.ago, error_class: "TypeError",
                            rota: "GET /posts", severidade: "warning")

    get admin_error_logs_path
    assert_equal [ novo.id, velho.id ], ids_de("error_logs"), "mais recente primeiro"

    get admin_error_logs_path(severidade: "warning")
    assert_equal [ novo.id ], ids_de("error_logs")

    get admin_error_logs_path(rota: "acoes")
    assert_equal [ velho.id ], ids_de("error_logs")

    get admin_error_logs_path(user_id: users(:ana).id.to_s)
    assert_equal [ velho.id ], ids_de("error_logs")

    get admin_error_logs_path(de: 2.days.ago.to_date.iso8601)
    assert_equal [ novo.id ], ids_de("error_logs")

    get admin_error_logs_path(ate: 2.days.ago.to_date.iso8601)
    assert_equal [ velho.id ], ids_de("error_logs")
  end

  test "detalhe do error_log traz payload e backtrace; a lista não" do
    sign_in users(:diretor)
    log = ErrorLog.create!(occurred_at: Time.current, error_class: "RuntimeError",
                           backtrace: "linha1\nlinha2", input_payload: { "a" => "1" })

    get admin_error_logs_path
    assert_not response.parsed_body["error_logs"].first.key?("backtrace")

    get admin_error_log_path(log)
    assert_equal "linha1\nlinha2", response.parsed_body["backtrace"]
    assert_equal({ "a" => "1" }, response.parsed_body["input_payload"])
  end

  # --- users/roles (RF-AUT-08/RN-15) ---

  test "diretoria concede escritor; papéis de gestão só pela presidência" do
    sign_in users(:diretor)
    patch admin_user_path(users(:ana)), params: { user: { role: "escritor" } }
    assert_response :success
    assert users(:ana).reload.escritor?

    patch admin_user_path(users(:ana)), params: { user: { role: "diretoria" } }
    assert_response :forbidden

    # tirar alguém da gestão também é da presidência
    patch admin_user_path(users(:diretor)), params: { user: { role: "membro" } }
    assert_response :forbidden, "não pode alterar o próprio papel"

    sign_in users(:presidente_user)
    patch admin_user_path(users(:ana)), params: { user: { role: "diretoria" } }
    assert_response :success
    assert users(:ana).reload.diretoria?
  end

  test "diretoria não rebaixa outra diretoria; papel inválido é 422" do
    users(:ana).update!(role: "diretoria")

    sign_in users(:diretor)
    patch admin_user_path(users(:ana)), params: { user: { role: "comunidade" } }
    assert_response :forbidden

    patch admin_user_path(users(:membro_user)), params: { user: { role: "imperador" } }
    assert_response :unprocessable_entity
  end

  test "busca de usuários por nome/email e papel" do
    sign_in users(:diretor)

    get admin_users_path(busca: "Elisa")
    assert_equal [ users(:escritor_user).id ], ids_de("users")

    get admin_users_path(role: "presidencia")
    assert_equal [ users(:presidente_user).id, users(:vice_user).id ].sort, ids_de("users").sort
  end

  # --- members e mandatos (RF-ADM-03) ---

  test "cria perfil de membro para conta sem perfil; duplicado é 422" do
    sign_in users(:diretor)

    assert_difference "Member.count", 1 do
      post admin_members_path, params: {
        member: { user_id: users(:membro_sem_perfil).id, bio: "Nova integrante.", founder: false }
      }
    end
    assert_response :created

    post admin_members_path, params: { member: { user_id: users(:membro_user).id } }
    assert_response :unprocessable_entity
  end

  test "atualiza tag de fundador (RN-04) e remove perfil" do
    sign_in users(:diretor)

    patch admin_member_path(members(:membro_comum)), params: { member: { founder: true } }
    assert_response :success
    assert members(:membro_comum).reload.founder

    assert_difference "Member.count", -1 do
      delete admin_member_path(members(:membro_comum))
    end
    assert_response :no_content
  end

  test "cria mandato respeitando RN-05 (coerência cargo × diretoria)" do
    sign_in users(:diretor)

    assert_difference "Mandato.count", 1 do
      post admin_mandatos_path, params: {
        mandato: { member_id: members(:membro_comum).id, gestao_id: gestoes(:antiga).id,
                   cargo: "membro", diretoria_id: diretorias(:cientifica).id }
      }
    end
    assert_response :created

    post admin_mandatos_path, params: {
      mandato: { member_id: members(:vice).id, gestao_id: gestoes(:antiga).id,
                 cargo: "presidente", diretoria_id: diretorias(:cientifica).id }
    }
    assert_response :unprocessable_entity, "presidente não pertence a diretoria (RN-05)"

    post admin_mandatos_path, params: {
      mandato: { member_id: members(:vice).id, gestao_id: gestoes(:antiga).id, cargo: "chefe" }
    }
    assert_response :unprocessable_entity, "cargo inválido é 422, não 500"
  end

  test "cria diretoria e nova gestão" do
    sign_in users(:diretor)

    post admin_diretorias_path, params: { diretoria: { nome: "Comunicação" } }
    assert_response :created

    post admin_gestoes_path, params: { gestao: { ano_inicio: 2030, ano_fim: 2031 } }
    assert_response :created

    post admin_gestoes_path, params: { gestao: { ano_inicio: 2035, ano_fim: 2035 } }
    assert_response :unprocessable_entity
  end

  # --- fila de aprovação (RF-ADM-04) ---

  test "fila de aprovação lista o que espera aprovação, mais antigo primeiro" do
    sign_in users(:diretor)
    get admin_approvals_path

    fila = response.parsed_body["posts"]
    assert_equal [ posts(:blog_em_aprovacao).id ], fila.map { |p| p["id"] }
    assert_equal "Elisa Escritora", fila.first["autor"]["name"]
  end

  # --- auditoria (RF-ADM-07) ---

  test "auditoria lista versões com diff e filtra por modelo e autor da mudança" do
    sign_in users(:diretor)
    patch acao_path(acoes(:acao_site)), params: { acao: { titulo: "Site novo" } }

    get admin_audits_path(item_type: "Acao")
    versao = response.parsed_body["versoes"].first
    assert_equal "Acao", versao["item_type"]
    assert_equal acoes(:acao_site).id, versao["item_id"]
    assert_equal users(:diretor).id.to_s, versao["whodunnit"]
    assert_equal [ "Site institucional da LEDS", "Site novo" ], versao["mudancas"]["titulo"]

    get admin_audits_path(user_id: "999999")
    assert_equal [], response.parsed_body["versoes"]
  end

  private

  def ids_de(chave)
    response.parsed_body[chave].map { |item| item["id"] }
  end
end
