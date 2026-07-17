require "test_helper"

class ParceriaLeadTest < ActiveSupport::TestCase
  def novo(**attrs)
    ParceriaLead.create!({ empresa: "ACME", contato_email: "contato@acme.example",
                           tipo: "software", descricao: "Quer patrocinar." }.merge(attrs))
  end

  test "converter! cria o parceiro, amarra os dois e marca convertido" do
    lead = novo

    parceiro = nil
    assert_difference "Parceiro.count", 1 do
      parceiro = lead.converter!
    end

    assert lead.convertido?
    assert_equal parceiro, lead.parceiro
    assert_equal "ACME", parceiro.nome
    assert parceiro.ativo?, "o parceiro nasce na vitrine"
  end

  test "converter! duas vezes é 422 (não duplica parceiro)" do
    lead = novo
    lead.converter!

    assert_no_difference "Parceiro.count" do
      assert_raises(ActiveRecord::RecordInvalid) { lead.converter! }
    end
  end

  test "recusar! fecha o lead sem criar parceiro" do
    lead = novo

    assert_no_difference "Parceiro.count" do
      lead.recusar!
    end
    assert lead.recusado?
  end

  test "lead recusado não pode ser convertido" do
    lead = novo
    lead.recusar!
    assert_raises(ActiveRecord::RecordInvalid) { lead.converter! }
  end

  test "tipo inválido é 422 (enum validate), não 500" do
    lead = ParceriaLead.new(empresa: "X", contato_email: "x@x.example", tipo: "doacao")
    assert_not lead.valid?
    assert lead.errors[:tipo].any?
  end
end
