require "test_helper"

# RF-PAR: vitrine pública, perfil com ações, formulário de lead, dashboard da
# gestão, conversão e área do parceiro.
class ParceirosTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # --- vitrine (RF-PAR-01) e perfil (RF-PAR-02) ---

  test "vitrine pública lista só os ativos" do
    get parceiros_path

    assert_response :success
    nomes = response.parsed_body["parceiros"].map { |p| p["nome"] }
    assert_equal [ "Inova Labs", "TechCorp" ], nomes.sort
    assert_not_includes nomes, "Parceiro Antigo", "inativo fica fora da vitrine"
  end

  test "gestão filtra parceiros por status; anônimo ignora o filtro" do
    get parceiros_path(status: "inativo")
    nomes = response.parsed_body["parceiros"].map { |p| p["nome"] }
    assert_not_includes nomes, "Parceiro Antigo", "filtro é ignorado para o público"

    sign_in users(:diretor)
    get parceiros_path(status: "inativo")
    assert_equal [ "Parceiro Antigo" ], response.parsed_body["parceiros"].map { |p| p["nome"] }
  end

  test "perfil do parceiro traz só as ações publicadas que ele apoia" do
    get parceiro_path(parceiros(:tech_corp))

    assert_response :success
    body = response.parsed_body
    assert_equal "TechCorp", body["nome"]
    ids = body["acoes"].map { |a| a["id"] }
    assert_equal [ acoes(:acao_hackathon).id ], ids, "acao_bot é rascunho — fica fora"
    # card no mesmo formato do índice de ações (Projeto/Evento/Artigo#card_json)
    assert body["acoes"].first.key?("detalhe"), "reusa o card do model"
  end

  test "perfil de parceiro inativo não é servido por id (index não pode ser furado)" do
    get parceiro_path(parceiros(:antigo))
    assert_response :forbidden

    sign_in users(:diretor)
    get parceiro_path(parceiros(:antigo))
    assert_response :success, "a gestão ainda enxerga para operar"
  end

  test "desativar tira o parceiro da ação pública também, não só da vitrine" do
    get acao_path(acoes(:acao_hackathon))
    nomes = response.parsed_body["parceiros"].map { |p| p["nome"] }
    assert_includes nomes, "TechCorp"

    parceiros(:tech_corp).update!(status: "inativo")

    get acao_path(acoes(:acao_hackathon))
    assert_empty response.parsed_body["parceiros"],
                 "inativo sai de TODO caminho público, senão a marca segue no ar"
  end

  test "user_id inexistente é 422, não 500 (violação de FK)" do
    sign_in users(:diretor)
    post parceiros_path, params: { parceiro: { nome: "X", user_id: 999_999 } }
    assert_response :unprocessable_entity
  end

  test "criar parceiro direto é da gestão" do
    sign_in users(:ana)
    post parceiros_path, params: { parceiro: { nome: "Spam", status: "ativo" } }
    assert_response :forbidden

    sign_in users(:diretor)
    assert_difference "Parceiro.count", 1 do
      post parceiros_path, params: { parceiro: { nome: "Nova Corp" } }
    end
    assert_response :created
  end

  test "duas contas no mesmo parceiro é 422 (User has_one :parceiro)" do
    parceiros(:tech_corp).update!(conta: users(:ana))

    outro = Parceiro.new(nome: "Clone", conta: users(:ana))
    assert_not outro.valid?
    assert outro.errors[:user_id].any?
  end

  # --- formulário público de lead (RF-PAR-03) ---

  test "qualquer um (sem login) manda o formulário de parceria e a gestão é notificada" do
    assert_difference "ParceriaLead.count", 1 do
      post parceria_leads_path, params: {
        parceria_lead: { empresa: "ACME", contato_email: "contato@acme.example", tipo: "patrocinio_geral" }
      }
    end
    assert_response :created

    lead = ParceriaLead.last
    assert lead.novo?
    assert_nil lead.parceiro_id, "lead não vira parceiro sozinho"
    assert users(:diretor).notifications.joins(:event)
                          .where(noticed_events: { type: "ParceriaLeadNotifier" }).exists?
  end

  test "lead com tipo inválido é 422" do
    post parceria_leads_path, params: {
      parceria_lead: { empresa: "X", contato_email: "x@x.example", tipo: "doacao" }
    }
    assert_response :unprocessable_entity
  end

  test "o formulário público não deixa forjar status nem parceiro_id" do
    post parceria_leads_path, params: {
      parceria_lead: { empresa: "ACME", contato_email: "c@acme.example", tipo: "software",
                       status: "convertido", parceiro_id: parceiros(:tech_corp).id }
    }
    assert_response :created

    lead = ParceriaLead.last
    assert lead.novo?, "status vem do default, não do payload — senão pula a triagem"
    assert_nil lead.parceiro_id
  end

  test "formulário público valida e-mail e teto de tamanho (fronteira sem login)" do
    post parceria_leads_path, params: {
      parceria_lead: { empresa: "X", contato_email: "nao-e-email", tipo: "software" }
    }
    assert_response :unprocessable_entity

    post parceria_leads_path, params: {
      parceria_lead: { empresa: "X", contato_email: "x@x.example", tipo: "software",
                       descricao: "a" * 5_001 }
    }
    assert_response :unprocessable_entity
  end

  # --- dashboard e conversão (RF-PAR-04) ---

  test "dashboard de leads exige gestão" do
    get admin_parceria_leads_path
    assert_response :redirect

    sign_in users(:membro_user)
    get admin_parceria_leads_path
    assert_response :forbidden

    sign_in users(:diretor)
    get admin_parceria_leads_path
    assert_response :success
  end

  test "converter lead cria o parceiro e o coloca na vitrine" do
    lead = ParceriaLead.create!(empresa: "ACME", contato_email: "c@acme.example", tipo: "software")

    sign_in users(:diretor)
    assert_difference "Parceiro.count", 1 do
      post converter_admin_parceria_lead_path(lead)
    end
    assert_response :success

    assert lead.reload.convertido?
    assert_equal "ACME", response.parsed_body["parceiro"]["nome"]

    get parceiros_path
    assert_includes response.parsed_body["parceiros"].map { |p| p["nome"] }, "ACME"
  end

  test "recusar lead não cria parceiro; converter depois é 422" do
    lead = ParceriaLead.create!(empresa: "ACME", contato_email: "c@acme.example", tipo: "software")

    sign_in users(:diretor)
    assert_no_difference "Parceiro.count" do
      post recusar_admin_parceria_lead_path(lead)
    end
    assert lead.reload.recusado?

    post converter_admin_parceria_lead_path(lead)
    assert_response :unprocessable_entity
  end

  # --- área do parceiro (RF-PAR-05) ---

  test "conta vinculada edita a própria vitrine, mas não o status" do
    parceiro = parceiros(:tech_corp)
    parceiro.update!(conta: users(:ana))

    sign_in users(:ana)
    patch parceiro_path(parceiro), params: { parceiro: { descricao: "Nova bio", status: "inativo" } }
    assert_response :success

    parceiro.reload
    assert_equal "Nova bio", parceiro.descricao
    assert parceiro.ativo?, "o parceiro não se despromove: status é da gestão"
  end

  test "terceiro não edita parceiro alheio" do
    sign_in users(:membro_user)
    patch parceiro_path(parceiros(:tech_corp)), params: { parceiro: { descricao: "hack" } }
    assert_response :forbidden
  end

  test "gestão edita status do parceiro" do
    sign_in users(:diretor)
    patch parceiro_path(parceiros(:tech_corp)), params: { parceiro: { status: "inativo" } }
    assert_response :success
    assert parceiros(:tech_corp).reload.inativo?
  end

  # --- vínculo ação ↔ parceiro (RF-PAR-02), junção auditada ---

  test "membro vincula parceiros à ação e a troca é auditada" do
    sign_in users(:membro_user)

    post acoes_path, params: {
      acao: {
        titulo: "Projeto com patrocínio",
        projeto: { situacao: "em_desenvolvimento" },
        parceiro_ids: [ parceiros(:tech_corp).id, parceiros(:inova_labs).id ]
      }
    }
    assert_response :created
    acao = Acao.find(response.parsed_body["id"])
    assert_equal 2, acao.parceiros.count

    # remover 1 parceiro gera 1 versão de destroy no PaperTrail (RNF-09) —
    # é o motivo do diff-writer em vez de delete_all, que não versiona
    assert_difference "PaperTrail::Version.where(item_type: 'AcaoParceiro').count", 1 do
      patch acao_path(acao), params: { acao: { parceiro_ids: [ parceiros(:inova_labs).id ] } }
    end
    assert_equal [ parceiros(:inova_labs).id ], acao.reload.parceiros.map(&:id)

    # esvaziar de propósito ([] no JSON) desvincula todos — e versiona
    assert_difference "PaperTrail::Version.where(item_type: 'AcaoParceiro').count", 1 do
      patch acao_path(acao), params: { acao: { parceiro_ids: [] } }, as: :json
    end
    assert_empty acao.reload.parceiros
  end

  test "apagar a ação leva as junções junto, com versão (RNF-09)" do
    acao = acoes(:acao_hackathon)
    assert acao.acao_parceiros.any?

    sign_in users(:diretor)
    assert_difference "PaperTrail::Version.where(item_type: 'AcaoParceiro').count", 1 do
      assert_difference "AcaoParceiro.count", -1 do
        acao.destroy!
      end
    end
  end

  test "apagar o lead convertido não derruba o parceiro (FK nullify)" do
    lead = ParceriaLead.create!(empresa: "ACME", contato_email: "c@acme.example", tipo: "software")
    parceiro = lead.converter!

    sign_in users(:diretor)
    assert_no_difference "Parceiro.count" do
      delete admin_parceria_lead_path(lead)
    end
    assert_response :no_content
    assert Parceiro.exists?(parceiro.id), "o parceiro sobrevive à eliminação do lead (LGPD)"
    assert_not Noticed::Event.where(type: "ParceriaLeadNotifier").exists?,
               "a eliminação leva as notificações sobre o lead junto (sem órfã)"
  end
end
