require "test_helper"

class MemberPolicyTest < ActiveSupport::TestCase
  test "leitura é pública (até deslogado)" do
    assert MemberPolicy.new(nil, Member).index?
    assert MemberPolicy.new(nil, Member).show?
  end

  test "gestão de membros é só diretoria e presidência" do
    assert_not MemberPolicy.new(users(:membro_user), Member).create?
    assert_not MemberPolicy.new(users(:ana), Member).update?
    assert MemberPolicy.new(users(:diretor), Member).create?
    assert MemberPolicy.new(users(:presidente_user), Member).destroy?
  end
end
