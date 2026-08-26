require "test_helper"

# As duas telas de sincronização. O caminho MAIS testado é o "Discord não
# configurado", porque é o estado real do projeto hoje: nenhum bot token foi
# criado ainda, e a tela não pode quebrar por isso.
class DiscordSincronizacaoTest < ActionDispatch::IntegrationTest
  # O ambiente já vem sem credenciais de Discord (ver test_helper).

  # ------------------------------------------------------------------ Perfil

  test "com Discord vinculado o botão fica ativo" do
    sign_in users(:ana) # tem oauth_identity de discord nas fixtures
    get profile_path

    assert_select "form[action=?] .btn-discord", sincronizar_discord_emblemas_path
    assert_select ".btn-sync-bloqueado", false, "com conta vinculada não pode aparecer bloqueado"
  end

  test "sem Discord vinculado o botão fica opaco e explica no hover" do
    sign_in users(:membro_user) # sem oauth_identity
    get profile_path

    assert_select ".btn-sync-bloqueado .btn-sync.opaco"
    assert_select ".btn-sync-aviso", /Sincronize sua conta do Discord/
    assert_select "form[action=?]", sincronizar_discord_emblemas_path, false
  end

  test "sincronizar exige login" do
    post sincronizar_discord_emblemas_path
    assert_redirected_to new_user_session_path
  end

  # Estado de hoje: sem bot configurado. Tem de virar aviso, não erro 500.
  test "sem Discord configurado, sincronizar avisa em vez de estourar" do
    sign_in users(:ana)
    post sincronizar_discord_emblemas_path

    assert_redirected_to profile_path(anchor: "emblemas")
    assert_match(/não deu para sincronizar/i, flash[:alert])
  end

  # ------------------------------------------------------------------ Painel

  test "a tela do painel exige gestão" do
    sign_in users(:membro_user)
    get painel_discord_path

    assert_redirected_to root_path
  end

  test "sem Discord configurado, o painel explica o que falta" do
    sign_in users(:diretor)
    get painel_discord_path

    assert_response :success
    assert_select ".painel-empty", /Discord não configurado/
    assert_select "body", /DISCORD_BOT_TOKEN/
  end

  test "sem Discord configurado, aplicar avisa em vez de estourar" do
    sign_in users(:diretor)
    post painel_discord_path

    assert_redirected_to painel_discord_path
    assert_match(/DISCORD_BOT_TOKEN/i, flash[:alert])
  end

  test "o botão do painel aparece bloqueado sem configuração" do
    sign_in users(:diretor)
    get painel_emblemas_path

    assert_select ".btn-sync-bloqueado .btn-sync.opaco"
    assert_select ".btn-sync-aviso", /DISCORD_BOT_TOKEN/
  end

  test "a lista de cargos gerenciados aparece mesmo sem configuração" do
    sign_in users(:diretor)
    get painel_discord_path

    # é a informação que diz o que a sincronização PODE apagar
    assert_select "table.painel-table tbody tr", DiscordCargo.count
  end

  # --------------------------------------------------------------- Marcador

  test "marcar espelhar no Discord grava" do
    sign_in users(:diretor)
    emblema = emblemas(:fundador_honorario)

    patch painel_emblema_path(emblema), params: { emblema: {
      nome: emblema.nome, icone_svg: emblema.icone_svg, cor: emblema.cor, efeito: "nenhum",
      tipo: "unico", peso: "1", ativo: "1", discord_sincronizar: "1"
    } }

    assert emblema.reload.discord_sincronizar?
  end

  # O id do cargo passou a ser resultado da sincronização: aceitar pelo
  # formulário deixaria o gestor apontar para um cargo que o site não gerencia.
  test "o id do cargo não entra mais pelo formulário" do
    sign_in users(:diretor)
    emblema = emblemas(:fundador_honorario)

    patch painel_emblema_path(emblema), params: { emblema: {
      nome: emblema.nome, icone_svg: emblema.icone_svg, cor: emblema.cor, efeito: "nenhum",
      tipo: "unico", peso: "1", ativo: "1", discord_role_id: "999999999999999999"
    } }

    assert_nil emblema.reload.discord_role_id
  end
end
