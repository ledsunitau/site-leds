require "test_helper"

class ComentarioTest < ActiveSupport::TestCase
  test "moderar! registra quem moderou e quando, sem apagar a linha" do
    comentario = comentarios(:visivel_na_noticia)

    assert_no_difference "Comentario.count", "soft delete: a linha fica (RF-NOV-10)" do
      comentario.moderar!("removido", members(:diretor_cientifica))
    end

    assert comentario.removido?
    assert_equal members(:diretor_cientifica), comentario.moderador
    assert comentario.moderated_at.present?
    assert_equal "Parabéns pela conquista!", comentario.corpo, "o rastro se preserva"
    assert_not Comentario.visiveis.exists?(comentario.id), "e some do público"
  end

  test "moderar! só AVANÇA: não revive, não rebaixa, não repete" do
    visivel = comentarios(:visivel_na_noticia)
    oculto = comentarios(:oculto_na_noticia)

    # alvo fora de oculto/removido
    assert_raises(ActiveRecord::RecordInvalid) { visivel.moderar!("visivel", members(:diretor_cientifica)) }
    assert_raises(ActiveRecord::RecordInvalid) { visivel.moderar!("inventado", members(:diretor_cientifica)) }

    # oculto → removido escala (ok); removido → oculto rebaixaria e apagaria
    # quem removeu de fato, então é barrado
    oculto.moderar!("removido", members(:pres))
    assert_raises(ActiveRecord::RecordInvalid) { oculto.moderar!("oculto", members(:diretor_cientifica)) }
    assert_equal members(:pres), oculto.reload.moderador, "o rastro de quem removeu fica"
  end

  test "moderar! resolve as denúncias pendentes do comentário (a aba não fica com pendência morta)" do
    comentario = comentarios(:visivel_na_noticia)
    d1 = comentario.denuncias.create!(denunciante: users(:membro_user), motivo: "spam")
    d2 = comentario.denuncias.create!(denunciante: users(:escritor_user), motivo: "spam")

    comentario.moderar!("oculto", members(:diretor_cientifica))

    assert d1.reload.resolvida?
    assert d2.reload.resolvida?
    assert_equal members(:diretor_cientifica), d1.resolvedor
  end

  test "só post publicado recebe comentário — regra no model, todo caminho de escrita" do
    invalido = Comentario.new(post: posts(:rascunho_do_membro), autor: users(:ana), corpo: "oi")
    assert_not invalido.valid?
    assert invalido.errors[:post].any?

    # o post sair do ar DEPOIS não trava moderar! (a validação é só on: :create)
    comentario = comentarios(:visivel_na_noticia)
    comentario.post.update_column(:status, "em_aprovacao")
    assert_nothing_raised { comentario.moderar!("oculto", members(:diretor_cientifica)) }
  end

  test "corpo é obrigatório e tem teto" do
    assert_not Comentario.new(post: posts(:noticia_publicada), autor: users(:ana)).valid?

    longo = Comentario.new(post: posts(:noticia_publicada), autor: users(:ana), corpo: "a" * 5_001)
    assert_not longo.valid?
    assert longo.errors[:corpo].any?
  end

  test "moderar é auditado (RF-ADM-07)" do
    comentario = comentarios(:visivel_na_noticia)

    assert_difference "PaperTrail::Version.where(item_type: 'Comentario').count", 1 do
      PaperTrail.request(whodunnit: users(:diretor).id.to_s) do
        comentario.moderar!("oculto", members(:diretor_cientifica))
      end
    end
    assert_equal users(:diretor).id.to_s, comentario.versions.last.whodunnit
  end

  test "apagar o post não deixa notificação órfã de denúncia" do
    comentarios(:visivel_na_noticia).denuncias.create!(denunciante: users(:membro_user), motivo: "spam")
    assert Noticed::Event.where(type: "DenunciaNotifier").exists?

    posts(:noticia_publicada).destroy!

    assert_not Noticed::Event.where(type: "DenunciaNotifier").exists?,
               "sem isto o sino da gestão apontaria para uma denúncia inexistente"
  end

  test "apagar o post leva comentários e denúncias junto — pelo callback, com versão" do
    comentarios(:visivel_na_noticia).denuncias.create!(denunciante: users(:membro_user), motivo: "spam")

    # a versão de destroy só existe se o dependent: :destroy do Rails rodar; o
    # ON DELETE CASCADE do banco apagaria as linhas SEM versionar (perdendo o
    # rastro de moderação). É isso que esta asserção separa.
    assert_difference "PaperTrail::Version.where(item_type: 'Comentario', event: 'destroy').count", 2 do
      assert_difference "Comentario.count", -2 do
        assert_difference "Denuncia.count", -2 do # 1 criada aqui + a fixture resolvida
          posts(:noticia_publicada).destroy!
        end
      end
    end
  end
end
