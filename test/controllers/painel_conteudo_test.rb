require "test_helper"

# Conteúdo no painel: ações (três tipos delegados), novidades e ideias.
# A escrita de ação passa pelo MESMO concern da API (EscritaDeAcao) — o que se
# testa aqui é o caminho por formulário, que manda hash indexado em vez de array.
class PainelConteudoTest < ActionDispatch::IntegrationTest
  test "as telas de conteúdo exigem gestão" do
    sign_in users(:membro_user)

    [ painel_acoes_path, painel_posts_path, painel_ideias_path ].each do |rota|
      get rota
      assert_redirected_to root_path, "#{rota} deveria barrar papel comum"
    end
  end

  # ---------------------------------------------------------------- Ações

  test "a lista de ações mostra rascunho e arquivada, que a rota pública esconde" do
    rascunho = Acao.create!(titulo: "Projeto em rascunho", status: "rascunho",
                            detalhe: Projeto.create!(situacao: "em_desenvolvimento"))

    sign_in users(:diretor)
    get painel_acoes_path
    assert_response :success
    assert_match rascunho.titulo, response.body

    # a fixture acao_bot já é rascunho; a rota pública mostra só publicadas
    get painel_acoes_path(status: "rascunho")
    assert_select "table.painel-table tbody tr", count: 2
  end

  test "cria projeto com stack e contribuições vindas de hash indexado" do
    sign_in users(:diretor)

    assert_difference -> { Acao.count }, 1 do
      post painel_acoes_path, params: {
        acao: {
          tipo: "projeto", titulo: "Portal novo", status: "publicada",
          projeto: { situacao: "em_desenvolvimento", link: "https://leds.dev" },
          tecnologia_ids: [ tecnologias(:ruby).id, "" ],
          # formulário manda hash indexado; a API manda array — o concern normaliza
          contribuicoes: {
            "0" => { member_id: members(:membro_comum).id, papel: "backend" },
            "zzz_marcador" => { member_id: "" }
          }
        }
      }
    end

    acao = Acao.find_by(titulo: "Portal novo")
    assert_equal "Projeto", acao.detalhe_type
    assert_equal [ tecnologias(:ruby).id ], acao.detalhe.tecnologia_ids
    assert_equal 1, acao.detalhe.contribuicoes.count, "a linha-marcador em branco não pode virar registro"
    assert_equal "backend", acao.detalhe.contribuicoes.first.papel
  end

  test "esvaziar uma coleção pela tela realmente esvazia" do
    acao = acoes(:acao_site)
    assert acao.detalhe.contribuicoes.any?, "fixture precisa ter contribuição"

    sign_in users(:diretor)
    patch painel_acao_path(acao), params: {
      acao: { titulo: acao.titulo, contribuicoes: { "zzz_marcador" => { member_id: "" } } }
    }

    assert_equal 0, acao.detalhe.reload.contribuicoes.count,
                 "só a linha-marcador chegou: a coleção tem de ficar vazia, não intacta"
  end

  test "cria evento com convidado e redes em texto" do
    sign_in users(:diretor)

    post painel_acoes_path, params: {
      acao: {
        tipo: "evento", titulo: "Semana da Computação", status: "publicada",
        evento: { local: "UNITAU", data_inicio: 2.days.from_now.change(sec: 0) },
        convidados: {
          "0" => { nome: "Convidada Externa", bio: "Pesquisadora",
                   redes_texto: "linkedin: https://linkedin.com/in/x\ngithub: https://github.com/x" },
          "zzz_marcador" => { nome: "" }
        }
      }
    }

    acao = Acao.find_by(titulo: "Semana da Computação")
    convidado = acao.detalhe.convidados.sole
    assert_equal "Convidada Externa", convidado.nome
    assert_equal %w[linkedin github], convidado.links.map(&:rede)
  end

  test "artigo respeita o limite de 1 a 3 temas" do
    sign_in users(:diretor)

    assert_no_difference -> { Acao.count } do
      post painel_acoes_path, params: {
        acao: { tipo: "artigo", titulo: "Sem tema", artigo: { situacao: "em_desenvolvimento" },
                tema_ids: [ "" ] }
      }
    end
    assert_match(/1 a 3 temas/, flash[:alert])
  end

  test "apagar ação leva o detalhe delegado junto" do
    acao = acoes(:acao_site)
    projeto_id = acao.detalhe_id

    sign_in users(:diretor)
    delete painel_acao_path(acao)

    assert_not Acao.exists?(acao.id)
    assert_not Projeto.exists?(projeto_id), "delegated_type dependent: :destroy"
  end

  # ------------------------------------------------------------ Novidades

  test "cria rascunho de novidade e envia para a fila" do
    sign_in users(:diretor)

    assert_difference -> { Post.count }, 1 do
      post painel_posts_path, params: { post: { tipo: "noticia", titulo: "Nova conquista", caller: "resumo" } }
    end
    novo = Post.find_by(titulo: "Nova conquista")
    assert novo.rascunho?, "nasce rascunho — publicar passa pela fila (RN-02)"

    post submeter_painel_post_path(novo)
    assert_redirected_to painel_aprovacoes_path
    assert novo.reload.em_aprovacao?
  end

  test "editar novidade publicada devolve para a fila e a tela avisa" do
    publicada = posts(:noticia_publicada)

    sign_in users(:diretor)
    patch painel_post_path(publicada), params: { post: { titulo: "Título revisado" } }

    assert publicada.reload.em_aprovacao?, "RN-02: edição de publicado volta para a fila"
    assert_match(/voltou para a fila/, flash[:notice])
  end

  test "histórico de versões renderiza o diff" do
    publicada = posts(:noticia_publicada)
    sign_in users(:diretor)
    patch painel_post_path(publicada), params: { post: { titulo: "Outro título" } }

    get versoes_painel_post_path(publicada)
    assert_response :success
    assert_select ".painel-diff"
  end

  # --------------------------------------------------------------- Ideias

  test "a tela de ideias mostra o funil e um card por ideia" do
    Ideia.create!(autor: users(:ana), tipo: "evento", titulo: "Semana de dados", descricao: "…")
    sign_in users(:diretor)

    get painel_ideias_path
    assert_response :success
    assert_select ".painel-ideias-resumo .painel-resumo", count: 4
    assert_select ".painel-ideia", count: Ideia.count
    # pendente: as duas decisões ficam na barra de ação do rodapé
    assert_select ".painel-ideia.pendente .painel-ideia-acoes .btn", count: 2
  end

  test "o CTA de virar ação fica no rodapé do card, e some depois de virar" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "App", descricao: "…")
    sign_in users(:diretor)
    post aprovar_painel_ideia_path(ideia)

    get painel_ideias_path
    assert_select ".painel-ideia-acoes a.painel-ideia-cta[href=?]",
                  new_painel_acao_path(tipo: "projeto", ideia_id: ideia.id),
                  count: 1

    post painel_acoes_path, params: {
      acao: { tipo: "projeto", titulo: "App (execução)", ideia_id: ideia.id,
              projeto: { situacao: "em_desenvolvimento" } }
    }

    get painel_ideias_path
    assert_select "a.painel-ideia-cta", count: 0, message: "ideia já vinculada não oferece criar de novo"
    assert_select ".painel-ideia-virou", count: 1
  end

  test "ideia de evento abre o formulário de evento, não de projeto" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "palestra", titulo: "Palestra X", descricao: "…")
    sign_in users(:diretor)
    post aprovar_painel_ideia_path(ideia)

    get painel_ideias_path
    assert_select "a.painel-ideia-cta[href=?]",
                  new_painel_acao_path(tipo: "evento", ideia_id: ideia.id)
  end

  test "ideia aprovada vira ação com o autor como idealizador" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "App da liga", descricao: "…")
    sign_in users(:diretor)

    post aprovar_painel_ideia_path(ideia)
    assert ideia.reload.aprovada?

    # a tela de ideias leva para cá com a ideia já escolhida: o idealizador é
    # fixado na CRIAÇÃO (acoes.ideia_id é imutável depois — ideia_id_imutavel)
    get new_painel_acao_path(tipo: "projeto", ideia_id: ideia.id)
    assert_response :success

    post painel_acoes_path, params: {
      acao: { tipo: "projeto", titulo: "App da liga (execução)", ideia_id: ideia.id,
              projeto: { situacao: "em_desenvolvimento" } }
    }
    assert_equal ideia, Acao.find_by(titulo: "App da liga (execução)").ideia
  end

  test "ideia pendente não pode virar origem de ação" do
    pendente = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Pendente", descricao: "…")
    sign_in users(:diretor)

    assert_no_difference -> { Acao.count } do
      post painel_acoes_path, params: {
        acao: { tipo: "projeto", titulo: "Cedo demais", ideia_id: pendente.id,
                projeto: { situacao: "em_desenvolvimento" } }
      }
    end
    assert_match(/aprovada/, flash[:alert])
  end

  test "a mesma ideia não serve a duas ações" do
    ideia = Ideia.create!(autor: users(:ana), tipo: "projeto", titulo: "Uma só", descricao: "…")
    sign_in users(:diretor)
    post aprovar_painel_ideia_path(ideia)

    post painel_acoes_path, params: {
      acao: { tipo: "projeto", titulo: "Primeira", ideia_id: ideia.id,
              projeto: { situacao: "em_desenvolvimento" } }
    }
    assert Acao.exists?(titulo: "Primeira")

    assert_no_difference -> { Acao.count } do
      post painel_acoes_path, params: {
        acao: { tipo: "projeto", titulo: "Segunda", ideia_id: ideia.id,
                projeto: { situacao: "em_desenvolvimento" } }
      }
    end
  end
end
