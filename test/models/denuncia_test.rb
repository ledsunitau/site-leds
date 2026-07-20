require "test_helper"

class DenunciaTest < ActiveSupport::TestCase
  # O índice parcial único (user_id, comentario_id) WHERE user_id IS NOT NULL
  # fecha a corrida que a validação app-level (nao_denunciar_duas_vezes) só pega
  # no caso não-concorrente. save(validate: false) simula os dois POSTs que
  # passaram a validação e colidem no banco.
  test "índice único: mesmo denunciante não duplica no mesmo comentário" do
    base = denuncias(:resolvida_antiga) # membro_user em oculto_na_noticia
    dup = Denuncia.new(comentario: base.comentario, denunciante: base.denunciante, motivo: "de novo")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "denúncias anonimizadas (user_id nil) convivem no mesmo comentário" do
    c = comentarios(:visivel_na_noticia)
    Denuncia.create!(comentario: c, motivo: "primeira anônima")
    assert_nothing_raised { Denuncia.create!(comentario: c, motivo: "segunda anônima") }
  end
end
