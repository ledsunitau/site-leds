require "test_helper"

class ProjetoTest < ActiveSupport::TestCase
  test "finalizado exige data de finalização (app e banco)" do
    projeto = projetos(:bot_discord)
    projeto.situacao = "finalizado"
    assert_not projeto.valid?
    assert projeto.errors[:data_finalizacao].any?

    assert_raises(ActiveRecord::StatementInvalid) do
      projeto.update_column(:situacao, "finalizado")
    end
  end

  test "em desenvolvimento não pode ter data de finalização" do
    projeto = projetos(:site_liga)
    projeto.situacao = "em_desenvolvimento"
    assert_not projeto.valid?
  end

  test "contribuição é única por projeto+membro+papel" do
    dup = Contribuicao.new(projeto: projetos(:site_liga),
                           member: members(:diretor_cientifica), papel: "backend")
    assert_not dup.valid?
    assert dup.errors.of_kind?(:papel, :taken)
  end

  test "mesmo membro pode ter outro papel no mesmo projeto" do
    outra = Contribuicao.new(projeto: projetos(:site_liga),
                             member: members(:diretor_cientifica), papel: "infra")
    assert outra.valid?
  end
end
