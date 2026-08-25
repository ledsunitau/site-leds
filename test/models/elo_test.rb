require "test_helper"

# Pontuação e elo: peso do emblema × peso do rank, degrau alcançado e o cargo
# do Discord que acompanha.
class EloTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "pontos = peso do emblema × peso do rank; emblema único conta ×1" do
    ana = users(:ana)
    ana.recalcular_elo!

    # fundador_honorario: peso 1, sem rank        → 1 × 1 = 1
    # maratonista:        peso 2, rank prata (3)  → 2 × 3 = 6
    assert_equal 7, ana.reload.pontos_emblemas
  end

  test "o elo é o maior degrau que os pontos alcançam" do
    ana = users(:ana)
    ana.recalcular_elo! # 7 pontos

    assert_equal "Prata", ana.reload.elo.nome, "5 <= 7 < 20"

    # sobe ao ouro do maratonista (peso 6): 1 + 2×6 = 13, ainda Prata
    emblemas(:maratonista).conceder!(ana, origem: "concessao")
    emblemas(:maratonista).conceder!(ana, origem: "concessao")
    assert_equal 13, ana.reload.pontos_emblemas
    assert_equal "Prata", ana.elo.nome

    # + o comprador pioneiro (peso 4) → 17: ainda Prata, o corte da Lenda é 20
    emblemas(:comprador_pioneiro).conceder!(ana, origem: "concessao")
    assert_equal 17, ana.reload.pontos_emblemas
    assert_equal "Prata", ana.elo.nome

    # um emblema pesado cruza o corte — e prova que o peso do emblema conta
    emblemas(:veterano).update!(peso: 10)
    emblemas(:veterano).conceder!(ana, origem: "concessao")
    assert_equal 27, ana.reload.pontos_emblemas
    assert_equal "Lenda", ana.elo.nome
  end

  test "revogar recalcula para baixo" do
    ana = users(:ana)
    ana.recalcular_elo!

    assert_difference -> { ana.reload.pontos_emblemas }, -6 do
      emblemas(:maratonista).revogar!(ana)
    end
  end

  test "sem emblema nenhum, zero pontos e o degrau de entrada" do
    dario = users(:diretor)
    dario.recalcular_elo!

    assert_equal 0, dario.reload.pontos_emblemas
    assert_equal "Ferro", dario.elo.nome, "o degrau de 0 pontos ainda é um degrau"
  end

  test "mudar de elo troca o cargo do Discord" do
    ana = users(:ana)
    ana.update_columns(pontos_emblemas: 0, elo_id: nil)

    assert_enqueued_with job: DiscordCargoJob,
                         args: [ ana.id, elos(:prata_elo).discord_role_id, "adicionar" ] do
      ana.recalcular_elo!
    end
  end

  test "recalcular sem mudança não enfileira cargo nem reescreve" do
    ana = users(:ana)
    ana.recalcular_elo!

    assert_no_enqueued_jobs only: DiscordCargoJob do
      3.times { ana.recalcular_elo! }
    end
  end

  # ------------------------------------------------------------- Ranking

  test "o elo final é o de maior pontuação e sustenta o top 1..N" do
    assert_equal "Lenda", Elo.final.nome
    assert elos(:lenda).final?
    assert_not elos(:prata_elo).final?

    ana = users(:ana)
    ana.update_columns(pontos_emblemas: 99, elo_id: elos(:lenda).id)
    users(:diretor).update_columns(pontos_emblemas: 50, elo_id: elos(:lenda).id)

    assert_equal 1, ana.posicao_no_topo
    assert_equal 2, users(:diretor).posicao_no_topo
    # quem não está no elo final não tem posição no topo
    assert_nil users(:membro_user).posicao_no_topo
  end

  test "Elo.para devolve o degrau certo nas bordas" do
    assert_equal "Ferro", Elo.para(0).nome
    assert_equal "Ferro", Elo.para(4).nome
    assert_equal "Prata", Elo.para(5).nome, "o corte é inclusivo: 5 já é Prata"
    assert_equal "Lenda", Elo.para(999).nome
  end

  test "proximo aponta o degrau seguinte, e nil no topo" do
    assert_equal "Prata", elos(:ferro).proximo.nome
    assert_nil elos(:lenda).proximo
  end
end
