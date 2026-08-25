require "test_helper"

# Emblemas no painel: CRUD, concessão a dedo, revogação e links exclusivos.
class PainelEmblemasTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.delete("emblemas/total_usuarios") }

  SVG_OK = '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="9"/></svg>'.freeze

  test "a tela exige gestão" do
    sign_in users(:membro_user)
    get painel_emblemas_path

    assert_redirected_to root_path
  end

  test "lista os emblemas com raridade e busca pelo nome" do
    sign_in users(:diretor)

    get painel_emblemas_path
    assert_select "table.painel-table tbody tr", count: Emblema.count

    get painel_emblemas_path(busca: "Veterano")
    assert_select "table.painel-table tbody tr", count: 1
  end

  test "cadastra um emblema e vai para a ficha dele" do
    sign_in users(:diretor)

    assert_difference -> { Emblema.count }, 1 do
      post painel_emblemas_path, params: { emblema: {
        nome: "Comentarista", icone_svg: SVG_OK, cor: "#1D84F5", efeito: "pulso",
        criterio: "comentarios", meta: "10", ativo: "1"
      } }
    end

    emblema = Emblema.find_by(nome: "Comentarista")
    assert_redirected_to edit_painel_emblema_path(emblema)
    assert_equal "comentarios", emblema.criterio
    assert_equal 10, emblema.meta
  end

  test "select de critério em branco vira emblema só de concessão" do
    sign_in users(:diretor)

    post painel_emblemas_path, params: { emblema: {
      nome: "Só na mão", icone_svg: SVG_OK, cor: "#00C55B", efeito: "nenhum",
      criterio: "", meta: "", ativo: "1"
    } }

    emblema = Emblema.find_by(nome: "Só na mão")
    assert_nil emblema.criterio
    assert_nil emblema.meta
  end

  test "o SVG é limpo na gravação pelo painel" do
    sign_in users(:diretor)

    post painel_emblemas_path, params: { emblema: {
      nome: "Sujo", cor: "#00C55B", efeito: "nenhum", ativo: "1",
      icone_svg: '<svg viewBox="0 0 24 24"><script>alert(1)</script><circle cx="1" cy="1" r="1"/></svg>'
    } }

    assert_no_match(/script/i, Emblema.find_by(nome: "Sujo").icone_svg)
  end

  test "concede a dedo pelo e-mail e recusa e-mail desconhecido" do
    sign_in users(:diretor)
    emblema = emblemas(:veterano)

    assert_difference -> { EmblemaUsuario.count }, 1 do
      post conceder_painel_emblema_path(emblema), params: { email: users(:membro_user).email }
    end
    assert_includes users(:membro_user).emblemas.reload, emblema
    # quem concedeu mora na CONQUISTA, não no vínculo: um escalonável tem várias
    assert_equal members(:diretor_cientifica), EmblemaConquista.last.concedido_por

    assert_no_difference -> { EmblemaUsuario.count } do
      post conceder_painel_emblema_path(emblema), params: { email: "ninguem@example.com" }
    end
    assert_match(/nenhuma conta/i, flash[:alert])
  end

  test "revoga de um usuário" do
    sign_in users(:diretor)

    assert_difference -> { EmblemaUsuario.count }, -1 do
      delete revogar_painel_emblema_path(emblemas(:fundador_honorario), user_id: users(:ana).id)
    end
    assert_not users(:ana).emblemas.reload.include?(emblemas(:fundador_honorario))
  end

  test "revogar limpa o emblema equipado do usuário" do
    users(:ana).update!(emblema_destaque: emblemas(:fundador_honorario))
    sign_in users(:diretor)

    delete revogar_painel_emblema_path(emblemas(:fundador_honorario), user_id: users(:ana).id)

    assert_nil users(:ana).reload.emblema_destaque_id
  end

  test "gera, desliga e remove link exclusivo" do
    sign_in users(:diretor)
    emblema = emblemas(:convidado_beta)

    assert_difference -> { EmblemaConvite.count }, 1 do
      post painel_emblema_convites_path(emblema), params: { expira_em: 1.week.from_now.iso8601 }
    end
    convite = EmblemaConvite.order(:created_at).last
    assert convite.token.present?, "o token nasce no model"
    assert convite.valido?

    patch painel_emblema_convite_path(emblema, convite), params: { ativo: "0" }
    assert_not convite.reload.valido?

    assert_difference -> { EmblemaConvite.count }, -1 do
      delete painel_emblema_convite_path(emblema, convite)
    end
  end

  test "excluir só é permitido enquanto ninguém tem o emblema" do
    sign_in users(:diretor)

    assert_difference -> { Emblema.count }, -1 do
      delete painel_emblema_path(emblemas(:veterano)) # usuarios_count = 0
    end

    assert_no_difference -> { Emblema.count } do
      delete painel_emblema_path(emblemas(:fundador_honorario)) # tem dono
    end
    assert_response :forbidden
  end

  # ---------------------------------------------- Ranks, elos e escalonáveis

  test "cria rank no catálogo e recusa apagar rank em uso" do
    sign_in users(:diretor)

    assert_difference -> { EmblemaRank.count }, 1 do
      post painel_emblema_ranks_path, params: { emblema_rank: {
        nome: "Esmeralda", cor: "#00C55B", efeito: "neon", peso: 10, ordem: 9
      } }
    end

    # elite não é usado por nenhum nível → sai
    assert_difference -> { EmblemaRank.count }, -1 do
      delete painel_emblema_rank_path(emblema_ranks(:elite))
    end

    # bronze está no maratonista → fica, com aviso
    assert_no_difference -> { EmblemaRank.count } do
      delete painel_emblema_rank_path(emblema_ranks(:bronze))
    end
    assert_match(/em uso/i, flash[:alert])
  end

  test "salvar rank reenfileira a varredura — o peso muda a base inteira" do
    sign_in users(:diretor)

    assert_enqueued_with job: EmblemasJob do
      patch painel_emblema_rank_path(emblema_ranks(:ouro)), params: {
        emblema_rank: { nome: "Ouro", cor: "#FFEE04", efeito: "brilho", peso: 12, ordem: 3 }
      }
    end
    assert_equal 12, emblema_ranks(:ouro).reload.peso
  end

  test "CRUD de elo e recálculo" do
    sign_in users(:diretor)

    assert_difference -> { Elo.count }, 1 do
      post painel_elos_path, params: { elo: {
        nome: "Diamante", cor: "#1D84F5", efeito: "neon", pontos_minimos: 50
      } }
    end
    assert_equal "Diamante", Elo.final.nome, "o de maior pontuação vira o final"

    assert_difference -> { Elo.count }, -1 do
      delete painel_elo_path(Elo.find_by(nome: "Diamante"))
    end
  end

  test "adiciona e remove nível de um emblema escalonável" do
    sign_in users(:diretor)
    emblema = emblemas(:maratonista)

    assert_difference -> { emblema.niveis.count }, 1 do
      post painel_emblema_niveis_path(emblema), params: {
        emblema_nivel: { rank_id: emblema_ranks(:elite).id, limiar: 10 }
      }
    end

    assert_difference -> { emblema.niveis.count }, -1 do
      delete painel_emblema_nivel_path(emblema, emblema_niveis(:maratonista_ouro))
    end
  end

  test "mexer no limiar reavalia quem já tem o emblema" do
    sign_in users(:diretor)
    # ana está no prata com 2 registros; tirar o prata a derruba para o bronze
    delete painel_emblema_nivel_path(emblemas(:maratonista), emblema_niveis(:maratonista_prata))

    assert_equal "Bronze", emblema_usuarios(:ana_maratonista).reload.nivel.nome
  end

  test "cadastrar escalonável ignora a meta digitada" do
    sign_in users(:diretor)

    post painel_emblemas_path, params: { emblema: {
      nome: "Competidor", icone_svg: SVG_OK, cor: "#00C55B", efeito: "nenhum",
      tipo: "escalonavel", peso: "3", meta: "7", ativo: "1"
    } }

    emblema = Emblema.find_by(nome: "Competidor")
    assert emblema.escalonavel?
    assert_nil emblema.meta, "escalonável não usa meta — o limiar fica no rank"
    assert_equal 3, emblema.peso
  end

  test "link com vagas e descrição" do
    sign_in users(:diretor)

    post painel_emblema_convites_path(emblemas(:maratonista)),
         params: { usos_max: "10", descricao: "Maratona X" }

    convite = EmblemaConvite.order(:created_at).last
    assert_equal 10, convite.usos_max
    assert_equal "Maratona X", convite.descricao
    assert_equal 10, convite.vagas_restantes
  end

  test "concessão a dedo grava descrição e data retroativa" do
    sign_in users(:diretor)

    post conceder_painel_emblema_path(emblemas(:maratonista)), params: {
      email: users(:membro_user).email, descricao: "Maratona de 2024",
      ocorrido_em: 2.years.ago.iso8601
    }

    conquista = EmblemaUsuario.find_by(emblema: emblemas(:maratonista), user: users(:membro_user))
                              .conquistas.first
    assert_equal "Maratona de 2024", conquista.descricao
    assert_equal 2.years.ago.to_date, conquista.ocorrido_em.to_date
  end

  test "concessão avisa quando o emblema está lotado" do
    sign_in users(:diretor)
    pioneiro = emblemas(:comprador_pioneiro) # teto 2
    [ users(:ana), users(:membro_user) ].each { |u| pioneiro.conceder!(u, origem: "concessao") }

    post conceder_painel_emblema_path(pioneiro), params: { email: users(:escritor_user).email }

    assert_match(/teto de 2/i, flash[:alert])
  end
end
