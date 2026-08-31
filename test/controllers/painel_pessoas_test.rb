require "test_helper"

# Pessoas no painel: contas/papéis, perfis de membro, mandatos e estrutura.
class PainelPessoasTest < ActionDispatch::IntegrationTest
  test "as telas de pessoas exigem gestão" do
    sign_in users(:membro_user)

    [ painel_usuarios_path, painel_membros_path, painel_estrutura_path ].each do |rota|
      get rota
      assert_redirected_to root_path, "#{rota} deveria barrar papel comum"
    end
  end

  test "a lista de usuários filtra por papel e busca" do
    sign_in users(:diretor)

    get painel_usuarios_path
    assert_select "table.painel-table tbody tr", count: User.count

    get painel_usuarios_path(role: "escritor")
    assert_select "table.painel-table tbody tr", count: 1

    get painel_usuarios_path(busca: "ana@")
    assert_select "table.painel-table tbody tr", count: 1
  end

  test "diretoria concede papel comum mas não papel de gestão" do
    sign_in users(:diretor)

    patch painel_usuario_path(users(:ana)), params: { user: { role: "escritor" } }
    assert_response :see_other
    assert users(:ana).reload.escritor?

    patch painel_usuario_path(users(:ana)), params: { user: { role: "diretoria" } }
    assert_response :see_other
    assert_match(/não pode conceder/, flash[:alert])
    assert users(:ana).reload.escritor?, "o papel não pode ter mudado"
  end

  test "presidência concede gestão; ninguém altera o próprio papel" do
    sign_in users(:presidente_user)

    patch painel_usuario_path(users(:ana)), params: { user: { role: "diretoria" } }
    assert users(:ana).reload.diretoria?

    patch painel_usuario_path(users(:presidente_user)), params: { user: { role: "membro" } }
    assert_match(/não pode conceder/, flash[:alert])
    assert users(:presidente_user).reload.presidencia?
  end

  test "criar perfil de membro leva para a ficha, onde se adiciona o mandato" do
    sign_in users(:diretor)

    assert_difference -> { Member.count }, 1 do
      post painel_membros_path, params: { member: { user_id: users(:ana).id, bio: "Nova integrante." } }
    end
    membro = Member.find_by(user: users(:ana))
    assert_redirected_to edit_painel_membro_path(membro)

    assert_difference -> { Mandato.count }, 1 do
      post painel_mandatos_path, params: { mandato: {
        member_id: membro.id, gestao_id: gestoes(:vigente).id, cargo: "diretor",
        diretoria_id: diretorias(:cientifica).id
      } }
    end
    assert_equal "diretor", membro.mandatos.last.cargo
  end

  test "RN-05: diretor sem diretoria é recusado com aviso na tela" do
    sign_in users(:diretor)

    assert_no_difference -> { Mandato.count } do
      post painel_mandatos_path, params: { mandato: {
        member_id: members(:membro_comum).id, gestao_id: gestoes(:antiga).id,
        cargo: "diretor", diretoria_id: ""
      } }
    end
    assert_response :see_other
    assert_match(/obrigatória para o cargo diretor/, flash[:alert])
  end

  test "RN-05: presidente COM diretoria também é recusado" do
    sign_in users(:diretor)

    assert_no_difference -> { Mandato.count } do
      post painel_mandatos_path, params: { mandato: {
        member_id: members(:membro_comum).id, gestao_id: gestoes(:antiga).id,
        cargo: "presidente", diretoria_id: diretorias(:cientifica).id
      } }
    end
    assert_match(/não se aplica/, flash[:alert])
  end

  test "editar membro atualiza bio e skills" do
    membro = members(:membro_comum)
    sign_in users(:diretor)

    patch painel_membro_path(membro), params: { member: {
      bio: "Bio nova.", founder: "1", tecnologia_ids: [ tecnologias(:ruby).id, "" ]
    } }

    membro.reload
    assert_equal "Bio nova.", membro.bio
    assert membro.founder?
    assert_equal [ tecnologias(:ruby).id ], membro.tecnologia_ids
  end

  # Os links do card (GitHub/LinkedIn/Lattes) só têm esta rota de escrita.
  test "editar membro grava os links do card" do
    membro = members(:membro_comum)
    sign_in users(:diretor)

    patch painel_membro_path(membro), params: { member: {
      github_url: "https://github.com/fulano", lattes_url: "http://lattes.cnpq.br/123"
    } }

    membro.reload
    assert_equal "https://github.com/fulano", membro.github_url
    assert_equal "http://lattes.cnpq.br/123", membro.lattes_url
  end

  # Vira href no card público: esquema que não seja http(s) não entra — nem
  # escondido depois de uma quebra de linha (o que $ deixaria passar).
  test "link do membro com esquema perigoso é recusado" do
    membro = members(:membro_comum)

    [ "javascript:alert(1)", "https://ok.com\njavascript:alert(1)" ].each do |perigoso|
      membro.github_url = perigoso
      assert_not membro.valid?, "#{perigoso.inspect} não podia passar"
      assert_includes membro.errors[:github_url].join, "http"
    end
  end

  test "remover perfil de membro preserva a conta" do
    membro = members(:membro_comum)
    conta = membro.user_id

    sign_in users(:diretor)
    assert_difference -> { Member.count }, -1 do
      delete painel_membro_path(membro)
    end
    assert User.exists?(conta), "a conta do usuário não pode ir junto"
  end

  test "estrutura cria e renomeia diretoria, mas não apaga a que tem mandatos" do
    sign_in users(:diretor)

    get painel_estrutura_path
    assert_response :success

    assert_difference -> { Diretoria.count }, 1 do
      post painel_diretorias_path, params: { diretoria: { nome: "Diretoria de Eventos" } }
    end
    nova = Diretoria.find_by(nome: "Diretoria de Eventos")

    patch painel_diretoria_path(nova), params: { diretoria: { nome: "Diretoria de Cultura" } }
    assert_equal "Diretoria de Cultura", nova.reload.nome

    # sem mandatos: apaga
    assert_difference -> { Diretoria.count }, -1 do
      delete painel_diretoria_path(nova)
    end

    # com mandatos: bloqueia (dependent: :nullify deixaria RN-05 inconsistente)
    assert_no_difference -> { Diretoria.count } do
      delete painel_diretoria_path(diretorias(:cientifica))
    end
    assert_match(/mandatos ligados/, flash[:alert])
  end

  test "gestão com mandatos não é apagada" do
    sign_in users(:diretor)

    assert_no_difference -> { Gestao.count } do
      delete painel_gestao_path(gestoes(:vigente))
    end
    assert_match(/tem mandatos/, flash[:alert])
  end

  test "ano_fim menor que ano_inicio vira aviso, não erro 500" do
    sign_in users(:diretor)

    assert_no_difference -> { Gestao.count } do
      post painel_gestoes_path, params: { gestao: { ano_inicio: 2030, ano_fim: 2029 } }
    end
    assert_match(/maior que o ano de início/, flash[:alert])
  end
end
