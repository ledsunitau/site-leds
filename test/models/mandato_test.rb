require "test_helper"

class MandatoTest < ActiveSupport::TestCase
  test "RN-05: presidente e vice não podem ter diretoria" do
    mandato = mandatos(:pres_vigente)
    mandato.diretoria = diretorias(:cientifica)
    assert_not mandato.valid?
    assert mandato.errors[:diretoria].any?
  end

  test "orientador não pode ter diretoria" do
    mandato = mandatos(:orientador_vigente)
    mandato.diretoria = diretorias(:midias)
    assert_not mandato.valid?
  end

  test "diretor e membro exigem diretoria (aresta do grafo, RN-06)" do
    mandato = mandatos(:diretor_vigente)
    mandato.diretoria = nil
    assert_not mandato.valid?
    assert mandato.errors[:diretoria].any?
  end

  test "um membro tem no máximo um mandato por gestão" do
    duplicado = Mandato.new(member: members(:pres), gestao: gestoes(:vigente), cargo: "membro",
                            diretoria: diretorias(:midias))
    assert_not duplicado.valid?
    assert duplicado.errors.of_kind?(:gestao_id, :taken)
  end

  test "cargo fora da lista é rejeitado" do
    assert_raises(ArgumentError) { Mandato.new(cargo: "estagiario") }
  end
end
