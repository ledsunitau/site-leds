require "test_helper"

class GestaoTest < ActiveSupport::TestCase
  test "vigente é a gestão que cobre o ano atual" do
    assert_equal gestoes(:vigente), Gestao.vigente
  end

  test "sem gestão cobrindo o ano atual, vale a mais recente" do
    Mandato.delete_all
    Gestao.delete_all
    antiga = Gestao.create!(ano_inicio: 2000, ano_fim: 2002)

    assert_equal antiga, Gestao.vigente
  end

  test "ano_fim deve ser maior que ano_inicio (app e banco)" do
    gestao = Gestao.new(ano_inicio: 2030, ano_fim: 2030)
    assert_not gestao.valid?

    assert_raises(ActiveRecord::StatementInvalid) do
      gestoes(:vigente).update_column(:ano_fim, gestoes(:vigente).ano_inicio)
    end
  end
end
