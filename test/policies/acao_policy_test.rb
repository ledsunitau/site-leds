require "test_helper"

class AcaoPolicyTest < ActiveSupport::TestCase
  test "publicada é visível para todos; rascunho só para membro+" do
    assert AcaoPolicy.new(nil, acoes(:acao_site)).show?
    assert_not AcaoPolicy.new(nil, acoes(:acao_bot)).show?
    assert_not AcaoPolicy.new(users(:ana), acoes(:acao_bot)).show?
    assert AcaoPolicy.new(users(:membro_user), acoes(:acao_bot)).show?
  end

  test "criar/editar é membro+; arquivar é diretoria+" do
    assert_not AcaoPolicy.new(users(:ana), Acao).create?
    assert AcaoPolicy.new(users(:membro_user), Acao).create?
    assert_not AcaoPolicy.new(users(:membro_user), acoes(:acao_site)).arquivar?
    assert AcaoPolicy.new(users(:diretor), acoes(:acao_site)).arquivar?
  end
end
