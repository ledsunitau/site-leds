require "test_helper"

class ComunidadeControllerTest < ActionDispatch::IntegrationTest
  test "exige login" do
    get comunidade_path
    assert_redirected_to new_user_session_path
  end

  test "logado: renderiza com o convite do Discord e o mascote" do
    sign_in users(:ana)
    get comunidade_path

    assert_response :success
    assert_select "a.btn-discord[href=?]", "https://discord.gg/jAnSTEXaqk"
    assert_select "img.comunidade-mascote"
  end
end
