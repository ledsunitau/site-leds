require "test_helper"

# Tamanho das variantes de foto (User#foto / Member#foto).
#
# Existe por causa de um bug real em produção: havia uma variante `:avatar`
# única de 96×96 servindo TODOS os usos de foto — inclusive o `.membro-foto`,
# que é 300×360 no card de /membros. O navegador ampliava 7,5× em tela HiDPI e
# a foto saía pixelada, mesmo com o upload em boa qualidade.
#
# A regressão é silenciosa: nada quebra, a imagem só fica feia. Por isso o teste
# crava os NÚMEROS, e não só "existe uma variante".
class FotoVariantesTest < ActiveSupport::TestCase
  # Maior consumo de cada variante, em CSS px (ver application.css), ×2 para
  # HiDPI — e a transformação que casa com o display:
  #   :avatar  → .perfil-avatar 84px (navbar 38, drawer 52, pódio 58). Display
  #              SEMPRE quadrado (círculo), então _fill: o corte no servidor é o
  #              mesmo que o object-fit:cover faria.
  #   :retrato → .membro-foto 300×360, que vira paisagem abaixo de 720px. A
  #              proporção inverte, então _limit e o corte fica com o CSS.
  ESPERADO = {
    avatar: { resize_to_fill: [ 192, 192 ] },
    retrato: { resize_to_limit: [ 720, 900 ] }
  }.freeze

  test "User e Member declaram as MESMAS variantes com os mesmos tamanhos" do
    [ User, Member ].each do |model|
      variantes = model.attachment_reflections["foto"].named_variants

      assert_equal ESPERADO.keys.sort, variantes.keys.sort,
                   "#{model}#foto precisa declarar exatamente #{ESPERADO.keys.inspect}"

      ESPERADO.each do |nome, esperado|
        transformacao, medidas = esperado.first
        assert_equal medidas, variantes[nome].transformations[transformacao],
                     "#{model}#foto :#{nome} mudou de tamanho ou de transformação"
      end
    end
  end

  # foto_para_card devolve a foto do Member OU a do User; quem consome pede a
  # variante sem saber de qual veio. Se só um dos dois declarar, o outro caminho
  # levanta ArgumentError em produção.
  test "as duas declarações são idênticas entre si" do
    assert_equal User.attachment_reflections["foto"].named_variants.transform_values { |v| v.transformations },
                 Member.attachment_reflections["foto"].named_variants.transform_values { |v| v.transformations }
  end

  test ":retrato cobre o box de 300x360 em 2x, :avatar não cobriria" do
    largura, altura = ESPERADO[:retrato][:resize_to_limit]
    assert_operator largura, :>=, 600, ".membro-foto tem 300px de largura; 2x pede 600"
    assert_operator altura, :>=, 720, ".membro-foto tem 360px de altura; 2x pede 720"

    # O contraste que documenta o bug: o que :avatar entregaria no mesmo box.
    assert_operator ESPERADO[:avatar][:resize_to_fill].first, :<, 600,
                    ":avatar é pequeno de propósito — por isso .membro-foto não pode usá-lo"
  end

  # O avatar do perfil (84px) é o maior consumo de :avatar; em 2x pede 168 nos
  # DOIS lados, porque o display é um círculo com object-fit:cover.
  test ":avatar cobre o avatar do perfil em 2x nos dois lados" do
    ESPERADO[:avatar][:resize_to_fill].each do |lado|
      assert_operator lado, :>=, 168, ".perfil-avatar tem 84px; 2x pede 168"
    end
  end
end
