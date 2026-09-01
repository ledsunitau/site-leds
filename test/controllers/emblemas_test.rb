require "test_helper"

# Catálogo, equipar, resgate de link exclusivo e página pública de usuário.
class EmblemasTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.delete("emblemas/total_usuarios") }

  # -------------------------------------------------------------- Catálogo

  test "as telas de emblema exigem login" do
    [ emblemas_path, usuario_path(users(:ana)),
      emblema_convite_path(emblema_convites(:beta_valido).token) ].each do |rota|
      get rota
      assert_redirected_to new_user_session_path, "#{rota} deveria exigir login"
    end
  end

  test "o catálogo esconde emblema exclusivo que o usuário não tem, e inativo de todos" do
    sign_in users(:ana)
    get emblemas_path

    assert_response :success
    assert_includes nomes_no_catalogo, "Fundador honorário"
    assert_not_includes nomes_no_catalogo, "Convidado beta", "exclusivo não desbloqueado não pode aparecer"
    assert_not_includes nomes_no_catalogo, "Emblema aposentado", "emblema inativo sai do catálogo"
  end

  test "exclusivo aparece no catálogo depois de desbloqueado" do
    emblemas(:convidado_beta).conceder!(users(:ana), origem: "convite")

    sign_in users(:ana)
    get emblemas_path

    assert_includes nomes_no_catalogo, "Convidado beta"
  end

  test "o card do escalonável mostra o rank alcançado ao lado do nome" do
    sign_in users(:ana) # tem 2 maratonas → prata (fixtures)
    get emblemas_path

    assert_includes nomes_no_catalogo, "Maratonista Prata"
  end

  test "emblema bloqueado sai como silhueta com o critério escrito" do
    sign_in users(:ana)
    get emblemas_path

    # o critério vem escrito, com a meta — é a instrução de como conseguir
    assert_select "article.emblema-card.bloqueado .emblema-como", "Dias de conta: 1000"
    assert_select ".emblema.bloqueado"
    # e emblema só de concessão diz isso em vez de inventar um critério
    assert_equal "Concedido pela gestão.", emblemas(:fundador_honorario).como_conseguir
  end

  # --------------------------------------------------------------- Equipar

  test "equipa destaque e secundário do próprio usuário" do
    diretor = users(:diretor)
    emblemas(:veterano).conceder!(diretor, origem: "concessao")
    emblemas(:fundador_honorario).conceder!(diretor, origem: "concessao")
    sign_in diretor

    patch equipar_emblemas_path, params: { user: {
      emblema_destaque_id: emblemas(:veterano).id,
      emblema_secundario_id: emblemas(:fundador_honorario).id
    } }

    assert_redirected_to profile_path(anchor: "emblemas")
    assert_equal emblemas(:veterano).id, diretor.reload.emblema_destaque_id
    assert_equal emblemas(:fundador_honorario).id, diretor.emblema_secundario_id
  end

  test "não equipa emblema que não desbloqueou" do
    sign_in users(:ana)

    patch equipar_emblemas_path, params: { user: { emblema_destaque_id: emblemas(:veterano).id } }

    assert_match(/só pode equipar/i, flash[:alert])
    assert_nil users(:ana).reload.emblema_destaque_id
  end

  test "campo vazio desequipa" do
    ana = users(:ana)
    ana.update!(emblema_destaque: emblemas(:fundador_honorario))
    sign_in ana

    patch equipar_emblemas_path, params: { user: { emblema_destaque_id: "", emblema_secundario_id: "" } }

    assert_nil ana.reload.emblema_destaque_id
  end

  # ---------------------------------------------------------------- Convite

  test "o link exclusivo concede o emblema e conta o uso" do
    convite = emblema_convites(:beta_valido)
    sign_in users(:ana)

    assert_difference -> { EmblemaUsuario.count }, 1 do
      get emblema_convite_path(convite.token)
    end

    assert_redirected_to emblemas_path
    assert_includes users(:ana).emblemas.reload, emblemas(:convidado_beta)
    assert_equal 1, convite.reload.usos
  end

  test "prefetch do navegador não resgata nem queima vaga" do
    convite = emblema_convites(:beta_valido)
    sign_in users(:ana)

    assert_no_difference -> { EmblemaUsuario.count } do
      get emblema_convite_path(convite.token), headers: { "X-Sec-Purpose" => "prefetch" }
      get emblema_convite_path(convite.token), headers: { "Sec-Purpose" => "prefetch;prerender" }
    end

    assert_equal 0, convite.reload.usos
  end

  test "resgatar duas vezes não duplica nem estoura" do
    sign_in users(:ana)
    2.times { get emblema_convite_path(emblema_convites(:beta_valido).token) }

    assert_equal 1, EmblemaUsuario.where(user: users(:ana), emblema: emblemas(:convidado_beta)).count
    assert_match(/já tem/i, flash[:notice])
  end

  test "link desligado e link vencido recusam com o motivo" do
    sign_in users(:ana)

    assert_no_difference -> { EmblemaUsuario.count } do
      get emblema_convite_path(emblema_convites(:beta_desligado).token)
      assert_match(/desativado/i, flash[:alert])

      get emblema_convite_path(emblema_convites(:beta_vencido).token)
      assert_match(/expirou/i, flash[:alert])
    end
  end

  test "token inexistente não vaza a existência do emblema" do
    sign_in users(:ana)
    get emblema_convite_path("naoexisteesse-token-aqui-000000000")

    assert_redirected_to root_path
    assert_match(/inválido/i, flash[:alert])
  end

  test "deslogado, o link guarda o destino e concede depois do login" do
    convite = emblema_convites(:beta_valido)

    get emblema_convite_path(convite.token)
    assert_redirected_to new_user_session_path

    # o Devise volta para o stored_location depois de autenticar
    post user_session_path, params: { user: { email: users(:ana).email, password: "senha-segura-123" } }
    follow_redirect!

    assert_includes users(:ana).emblemas.reload, emblemas(:convidado_beta)
  end

  # --------------------------------------------------------- Perfil público

  test "a página pública mostra emblemas equipados e nunca o e-mail" do
    ana = users(:ana)
    ana.update!(emblema_destaque: emblemas(:fundador_honorario))
    sign_in users(:diretor)

    get usuario_path(ana)

    assert_response :success
    assert_select ".perfil-nome", /Ana Comunidade/
    assert_select ".perfil-equipados .emblema"
    assert_no_match ana.email, response.body
  end

  # ------------------------------------------------------------ Aba do perfil

  test "a aba Emblemas aparece no Meu perfil com os desbloqueados" do
    sign_in users(:ana)
    get profile_path

    assert_select "button.perfil-tab[data-vista=emblemas]"
    # ana tem o fundador honorário e o maratonista (fixtures)
    assert_select ".perfil-panel[data-vista=emblemas] .emblema-card", 2
  end

  private

  # O <h4> do card carrega o nome E o chip do rank, então o texto vem com
  # quebras de linha: squish devolve "Maratonista Prata" / "Fundador honorário".
  def nomes_no_catalogo = css_select(".emblema-nome").map { |n| n.text.squish }
end
