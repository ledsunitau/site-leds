require "test_helper"

# Fase de moderação do painel: aprovações, denúncias, comentários, avaliações.
# As escritas chamam os métodos de model já existentes — o que se testa aqui é
# o caminho HTTP (gate, redirect 303, mensagem) e a autoria em members.
class PainelModeracaoTest < ActionDispatch::IntegrationTest
  test "as telas de moderação exigem gestão" do
    sign_in users(:membro_user)

    [ painel_aprovacoes_path, painel_denuncias_path, painel_comentarios_path, painel_avaliacoes_path ].each do |rota|
      get rota
      assert_redirected_to root_path, "#{rota} deveria barrar papel comum"
    end
  end

  test "a fila lista posts em aprovação e ideias pendentes" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "App da liga",
                          descricao: "Um app para acompanhar os eventos.")

    sign_in users(:diretor)
    get painel_aprovacoes_path

    assert_response :success
    assert_select ".painel-fila-titulo", text: posts(:blog_em_aprovacao).titulo
    assert_select ".painel-fila-titulo", text: ideia.titulo
  end

  test "aprovar publica o post e registra quem liberou" do
    post_na_fila = posts(:blog_em_aprovacao)

    sign_in users(:diretor)
    post painel_aprovacoes_aprovar_post_path(post_na_fila)

    assert_redirected_to painel_aprovacoes_path
    post_na_fila.reload
    assert post_na_fila.publicado?
    assert_equal members(:diretor_cientifica), post_na_fila.aprovador
    assert post_na_fila.published_at.present?
  end

  test "rejeitar devolve o post ao autor" do
    sign_in users(:diretor)
    post painel_aprovacoes_rejeitar_post_path(posts(:blog_em_aprovacao))

    assert_redirected_to painel_aprovacoes_path
    assert posts(:blog_em_aprovacao).reload.rejeitado?
  end

  test "transição inválida vira aviso na tela, não JSON" do
    sign_in users(:diretor)
    # já publicado: aprovar de novo é transição inválida (RecordInvalid)
    post painel_aprovacoes_aprovar_post_path(posts(:noticia_publicada))

    assert_response :see_other
    assert_match(/não pode ir de/, flash[:alert])
    assert posts(:noticia_publicada).reload.publicado?
  end

  test "gestor sem perfil de membro é avisado em vez de estourar" do
    sem_perfil = users(:membro_sem_perfil)
    sem_perfil.update!(role: "diretoria")

    sign_in sem_perfil
    post painel_aprovacoes_aprovar_post_path(posts(:blog_em_aprovacao))

    assert_response :see_other
    assert_match(/perfil de membro/, flash[:alert])
    assert posts(:blog_em_aprovacao).reload.em_aprovacao?, "não pode ter aprovado sem autoria"
  end

  test "aprovar ideia registra o revisor" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "pesquisa", titulo: "Estudo de grafos",
                          descricao: "Pesquisa sobre caminhos mínimos.")

    sign_in users(:diretor)
    post painel_aprovacoes_aprovar_ideia_path(ideia)

    ideia.reload
    assert ideia.aprovada?
    assert_equal members(:diretor_cientifica), ideia.revisor
  end

  test "denúncias mostram as pendentes e moderar o comentário resolve junto" do
    denuncia = Denuncia.create!(comentario: comentarios(:visivel_na_noticia),
                                denunciante: users(:ana), motivo: "spam")

    sign_in users(:diretor)
    get painel_denuncias_path
    assert_response :success
    assert_select ".painel-citacao", text: comentarios(:visivel_na_noticia).corpo

    post moderar_painel_comentario_path(comentarios(:visivel_na_noticia), status: "oculto")
    assert_response :see_other

    assert comentarios(:visivel_na_noticia).reload.oculto?
    assert denuncia.reload.resolvida?, "moderar o comentário resolve as denúncias dele"
  end

  test "resolver improcedente não mexe no comentário" do
    denuncia = Denuncia.create!(comentario: comentarios(:visivel_na_noticia),
                                denunciante: users(:ana), motivo: "não gostei")

    sign_in users(:diretor)
    post resolver_painel_denuncia_path(denuncia)

    assert denuncia.reload.resolvida?
    assert comentarios(:visivel_na_noticia).reload.visivel?, "improcedente não tira do ar"
  end

  test "a lista de comentários filtra por status e busca" do
    sign_in users(:diretor)

    get painel_comentarios_path
    assert_select "table.painel-table tbody tr", count: Comentario.count

    get painel_comentarios_path(status: "oculto")
    assert_select "table.painel-table tbody tr", count: 1

    get painel_comentarios_path(busca: "Parabéns")
    assert_select "table.painel-table tbody tr", count: 1
  end

  test "avaliações listam e removem" do
    avaliacao = Avaliacao.new(produto: produtos(:camiseta), autor: users(:ana), nota: 1,
                              comentario: "texto abusivo")
    avaliacao.save!(validate: false) # a validação exige compra; aqui o alvo é a moderação

    sign_in users(:diretor)
    get painel_avaliacoes_path
    assert_response :success

    assert_difference -> { Avaliacao.count }, -1 do
      delete painel_avaliacao_path(avaliacao)
    end
    assert_redirected_to painel_avaliacoes_path
  end
end
