require "test_helper"

class IdeiaTest < ActiveSupport::TestCase
  def nova(**attrs)
    Ideia.create!({ autor: users(:ana), tipo: "projeto", titulo: "App da liga" }.merge(attrs))
  end

  test "aprovar! registra revisor e data e muda o status" do
    ideia = nova
    assert ideia.pendente?

    ideia.aprovar!(members(:diretor_cientifica))
    assert ideia.aprovada?
    assert_equal members(:diretor_cientifica), ideia.revisor
    assert ideia.reviewed_at.present?
  end

  test "rejeitar! muda para rejeitada" do
    ideia = nova(tipo: "pesquisa")
    ideia.rejeitar!(members(:diretor_cientifica))
    assert ideia.rejeitada?
  end

  test "revisar ideia já revisada é 422 (só pendente pode ser revisada)" do
    ideia = nova(status: "aprovada")
    assert_raises(ActiveRecord::RecordInvalid) { ideia.aprovar!(members(:diretor_cientifica)) }
  end

  test "tipo inválido é 422 (enum validate), não 500" do
    ideia = Ideia.new(autor: users(:ana), tipo: "parceiro", titulo: "Z")
    assert_not ideia.valid?
    assert ideia.errors[:tipo].any?, "o erro é do enum tipo, não de outro atributo"
  end

  # --- vínculo idealizador (RF-ACO-07) ---

  test "ação só vincula ideia aprovada e no máximo uma vez" do
    aprovada = nova(status: "aprovada")
    pendente = nova(status: "pendente")

    # ideia não aprovada não pode virar ação
    acao_invalida = Acao.new(titulo: "X", detalhe: Projeto.new, ideia: pendente)
    assert_not acao_invalida.valid?
    assert_includes acao_invalida.errors[:ideia], "precisa estar aprovada"

    # aprovada vincula
    Acao.create!(titulo: "Vira ação", detalhe: Projeto.new, ideia: aprovada)
    # segunda ação para a MESMA ideia é barrada (máx 1)
    segunda = Acao.new(titulo: "De novo", detalhe: Projeto.new, ideia: aprovada)
    assert_not segunda.valid?
    assert segunda.errors[:ideia_id].any?, "ideia_id único: uma ideia → no máx uma ação"
  end

  test "idealizador é imutável após a criação da ação" do
    a = nova(status: "aprovada")
    b = nova(status: "aprovada")
    acao = Acao.create!(titulo: "Da ideia A", detalhe: Projeto.new, ideia: a)

    acao.ideia = b
    assert_not acao.valid?
    assert acao.errors[:ideia_id].any?, "não re-aponta o idealizador depois"
  end
end
