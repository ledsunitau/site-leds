require "test_helper"

# Cosmético: a pintura exclusiva que o emblema desbloqueia, e a escolha do
# usuário sobre qual vestir.
class EmblemaCosmeticoTest < ActiveSupport::TestCase
  # --------------------------------------------------------- Exclusividade

  test "dois emblemas não podem ter o mesmo gradiente" do
    repetido = Emblema.new(nome: "Cópia", icone_svg: "<svg viewBox='0 0 24 24'></svg>",
                           cor: "#123456", efeito: "nenhum",
                           cosmetico_gradiente: emblemas(:veterano).cosmetico_gradiente)

    assert_not repetido.valid?
    assert_match(/exclusiva/i, repetido.errors[:cosmetico_gradiente].to_sentence)
  end

  test "a normalização impede colisão disfarçada por espaço e caixa" do
    emblema = Emblema.create!(nome: "Normalizado", icone_svg: "<svg viewBox='0 0 24 24'></svg>",
                              cor: "#123456", efeito: "nenhum",
                              cosmetico_gradiente: "#ff6b00, #ffd200")

    assert_equal "#FF6B00,#FFD200", emblema.cosmetico_gradiente

    gemeo = Emblema.new(nome: "Gêmeo", icone_svg: "<svg viewBox='0 0 24 24'></svg>",
                        cor: "#654321", efeito: "nenhum",
                        cosmetico_gradiente: "  #FF6B00,#ffd200  ")
    assert_not gemeo.valid?, "mesma pintura escrita diferente ainda é a mesma pintura"
  end

  # insert_all! (com bang): o sem-bang usa ON CONFLICT DO NOTHING e engoliria
  # a colisão em silêncio, sem provar que o índice existe.
  test "o índice único é o backstop da corrida" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Emblema.insert_all!([ { nome: "Bruto", icone_svg: "<svg/>", cor: "#111111", efeito: "nenhum",
                             cosmetico_gradiente: emblemas(:veterano).cosmetico_gradiente,
                             cosmetico_movimento: "parado", cosmetico_velocidade: 4,
                             tipo: "unico", peso: 1, ativo: true, exclusivo: false,
                             usuarios_count: 0, created_at: Time.current, updated_at: Time.current } ])
    end
  end

  test "emblema sem cosmético é válido — nem todo emblema dá cor" do
    assert emblemas(:aposentado).cosmetico_gradiente.blank?
    assert emblemas(:aposentado).valid?
    assert_not emblemas(:aposentado).cosmetico?
  end

  # ---------------------------------------------------------------- Formato

  test "o gradiente exige 2 ou 3 cores hexadecimais" do
    emblema = emblemas(:aposentado)

    assert_not emblema.update(cosmetico_gradiente: "#FF0000")
    assert_not emblema.update(cosmetico_gradiente: "#FF0000,#00FF00,#0000FF,#FFFFFF")
    assert_not emblema.update(cosmetico_gradiente: "vermelho,azul")
    assert emblema.update(cosmetico_gradiente: "#FF0000,#00FF00")
    assert emblema.update(cosmetico_gradiente: "#FF0000,#00FF00,#0000FF")
  end

  test "movimento fora da lista e velocidade fora da faixa são recusados" do
    emblema = emblemas(:veterano)

    assert_not emblema.update(cosmetico_movimento: "explodir")
    assert_not emblema.update(cosmetico_velocidade: 0)
    assert_not emblema.update(cosmetico_velocidade: 99)
    assert emblema.update(cosmetico_movimento: "fluxo", cosmetico_velocidade: 8)
  end

  test "o CSS emenda a primeira cor no fim para o fluxo não ter costura" do
    assert_equal "linear-gradient(100deg, #00C55B, #7CF0B0, #00C55B)",
                 emblemas(:primeira_novidade).cosmetico_css
  end

  test "gradiente que já fecha o ciclo não ganha parada repetida" do
    # senão sairia "…#1D84F5, #1D84F5" — um trecho chapado no meio da animação
    assert_equal "linear-gradient(100deg, #1D84F5, #8AC6FF, #1D84F5)",
                 emblemas(:veterano).cosmetico_css
  end

  # ------------------------------------------------------- Escolha do usuário

  test "só veste pintura de emblema desbloqueado, nos dois slots" do
    ana = users(:ana) # tem fundador_honorario e maratonista; não tem veterano

    assert_not ana.update(emblema_nome: emblemas(:veterano))
    # reload entre as tentativas: um update que falha deixa o atributo inválido
    # atribuído em memória, e ele reprovaria a tentativa seguinte
    assert_not ana.reload.update(emblema_halo: emblemas(:veterano))

    assert ana.reload.update(emblema_nome: emblemas(:fundador_honorario))
    assert ana.update(emblema_halo: emblemas(:maratonista))
  end

  # É o ponto da separação: a cor do nome de um emblema e o halo de outro.
  test "nome e halo podem vir de emblemas diferentes" do
    ana = users(:ana)

    assert ana.update(emblema_nome: emblemas(:fundador_honorario),
                      emblema_halo: emblemas(:maratonista))
    assert_equal emblemas(:fundador_honorario).id, ana.reload.emblema_nome_id
    assert_equal emblemas(:maratonista).id, ana.emblema_halo_id
  end

  test "não veste emblema que não tem pintura" do
    ana = users(:ana)
    emblemas(:fundador_honorario).update!(cosmetico_gradiente: nil)

    assert_not ana.update(emblema_nome: emblemas(:fundador_honorario))
    assert_match(/não tem cor/i, ana.errors[:emblema_nome_id].to_sentence)

    assert_not ana.update(emblema_halo: emblemas(:fundador_honorario))
    assert_match(/não tem cor/i, ana.errors[:emblema_halo_id].to_sentence)
  end

  test "nenhuma pintura é uma escolha válida" do
    ana = users(:ana)
    ana.update!(emblema_nome: emblemas(:fundador_honorario), emblema_halo: emblemas(:maratonista))

    assert ana.update(emblema_nome: nil, emblema_halo: nil)
    assert_nil ana.reload.emblema_nome_id
    assert_nil ana.emblema_halo_id
  end

  # O destaque virou vitrine: quem pinta é a escolha de cor, à parte.
  test "destaque e pintura são independentes" do
    ana = users(:ana)

    assert ana.update(emblema_destaque: emblemas(:maratonista),
                      emblema_nome: emblemas(:fundador_honorario))
    assert_equal emblemas(:maratonista).id, ana.reload.emblema_destaque_id
    assert_equal emblemas(:fundador_honorario).id, ana.emblema_nome_id
  end

  test "revogar o emblema limpa TODOS os slots que apontavam para ele" do
    ana = users(:ana)
    ana.update!(emblema_destaque: emblemas(:fundador_honorario),
                emblema_nome: emblemas(:fundador_honorario),
                emblema_halo: emblemas(:fundador_honorario))

    emblemas(:fundador_honorario).revogar!(ana)

    ana.reload
    User::SLOTS.each do |slot|
      assert_nil ana.public_send(slot),
                 "#{slot} não pode sobreviver à revogação do emblema"
    end
  end
end
