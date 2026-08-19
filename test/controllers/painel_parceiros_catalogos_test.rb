require "test_helper"

# Parceiros, leads e catálogos no painel.
class PainelParceirosCatalogosTest < ActionDispatch::IntegrationTest
  test "as telas exigem gestão" do
    sign_in users(:membro_user)

    [ painel_parceiros_path, painel_leads_path, painel_catalogos_path ].each do |rota|
      get rota
      assert_redirected_to root_path, "#{rota} deveria barrar papel comum"
    end
  end

  # ----------------------------------------------------------- Parceiros

  test "cadastra, edita e apaga parceiro" do
    sign_in users(:diretor)

    get painel_parceiros_path
    assert_response :success

    assert_difference -> { Parceiro.count }, 1 do
      post painel_parceiros_path, params: { parceiro: {
        nome: "Empresa X", site_url: "https://x.com", status: "ativo", depoimento: "Ótima parceria."
      } }
    end
    parceiro = Parceiro.find_by(nome: "Empresa X")

    patch painel_parceiro_path(parceiro), params: { parceiro: { nome: "Empresa X", status: "inativo" } }
    assert parceiro.reload.inativo?

    assert_difference -> { Parceiro.count }, -1 do
      delete painel_parceiro_path(parceiro)
    end
  end

  test "apagar parceiro leva o vínculo com a ação, mas não a ação" do
    parceiro = parceiros(:tech_corp)
    AcaoParceiro.find_or_create_by!(acao: acoes(:acao_site), parceiro: parceiro)
    vinculos = parceiro.acao_parceiros.count
    assert vinculos.positive?

    sign_in users(:diretor)
    assert_difference -> { AcaoParceiro.count }, -vinculos do
      delete painel_parceiro_path(parceiro)
    end
    assert Acao.exists?(acoes(:acao_site).id), "a ação apoiada continua existindo"
  end

  test "duas contas não podem apontar para o mesmo parceiro" do
    sign_in users(:diretor)
    parceiros(:tech_corp).update!(conta: users(:parceiro_user))

    post painel_parceiros_path, params: { parceiro: {
      nome: "Outra", status: "ativo", user_id: users(:parceiro_user).id
    } }
    assert_response :see_other
    assert flash[:alert].present?
  end

  # --------------------------------------------------------------- Leads

  test "lead aceito vira parceiro; recusar e eliminar também funcionam" do
    lead = ParceriaLead.create!(empresa: "Startup Y", contato_nome: "Yara",
                                contato_email: "yara@y.com", tipo: "software",
                                descricao: "Queremos um sistema.")
    sign_in users(:diretor)

    get painel_leads_path
    assert_response :success

    assert_difference -> { Parceiro.count }, 1 do
      post converter_painel_lead_path(lead)
    end
    assert_equal "convertido", lead.reload.status
    assert_redirected_to painel_parceiros_path

    outro = ParceriaLead.create!(empresa: "Z", contato_nome: "Zeca", contato_email: "z@z.com",
                                 tipo: "evento", descricao: "…")
    post recusar_painel_lead_path(outro)
    assert_equal "recusado", outro.reload.status

    # LGPD art. 18: o lead guarda dados de contato de uma pessoa
    assert_difference -> { ParceriaLead.count }, -1 do
      delete painel_lead_path(outro)
    end
  end

  # ----------------------------------------------------------- Catálogos

  test "catálogos criam, renomeiam e apagam os três tipos" do
    sign_in users(:diretor)

    get painel_catalogos_path
    assert_response :success

    assert_difference -> { Tecnologia.count }, 1 do
      post painel_criar_catalogo_path(tipo: "tecnologias"), params: { item: { nome: "Elixir" } }
    end
    tec = Tecnologia.find_by(nome: "Elixir")

    # antes desta tela, tecnologia era create-only: um erro de digitação era permanente
    patch painel_catalogo_item_path(tipo: "tecnologias", id: tec.id), params: { item: { nome: "Elixir/OTP" } }
    assert_equal "Elixir/OTP", tec.reload.nome

    assert_difference -> { Tecnologia.count }, -1 do
      delete painel_catalogo_item_path(tipo: "tecnologias", id: tec.id)
    end

    assert_difference -> { Tema.count }, 1 do
      post painel_criar_catalogo_path(tipo: "temas"), params: { item: { nome: "Compiladores" } }
    end

    assert_difference -> { Congresso.count }, 1 do
      post painel_criar_catalogo_path(tipo: "congressos"), params: { item: { nome: "SBES" } }
    end
  end

  test "tipo de catálogo desconhecido é recusado, sem constantize" do
    sign_in users(:diretor)

    post painel_criar_catalogo_path(tipo: "users"), params: { item: { nome: "hack" } }
    assert_redirected_to painel_catalogos_path
    assert_match(/desconhecido/, flash[:alert])
  end

  test "congresso com apresentação não é apagado" do
    congresso = congressos(:cicted)
    sign_in users(:diretor)

    assert_no_difference -> { Congresso.count } do
      delete painel_catalogo_item_path(tipo: "congressos", id: congresso.id)
    end
    assert flash[:alert].present?
  end

  test "nome duplicado no catálogo vira aviso, não 500" do
    sign_in users(:diretor)

    assert_no_difference -> { Tecnologia.count } do
      post painel_criar_catalogo_path(tipo: "tecnologias"), params: { item: { nome: tecnologias(:ruby).nome } }
    end
    assert flash[:alert].present?
  end
end
