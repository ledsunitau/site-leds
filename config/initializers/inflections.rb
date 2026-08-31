# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# Nomes de domínio em português que o inflector inglês erra:
#   - "-ao" ganha "s" simples (gestao -> "gestaos");
#   - "-ia" E "-ta" são tratados como plural latino e ficam IGUAIS (a regra
#     default é /([ti])a$/, para criteria/media): diretoria -> "diretoria",
#     conquista -> "conquista";
#   - "-l" ganha "s" em vez de "-is" (nivel -> "nivels").
# Toda branch que criar tabela com nome em português DEVE conferir o plural aqui.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "item_carrinho", "itens_carrinho"
  inflect.irregular "item_pedido", "itens_pedido"
  inflect.irregular "gestao", "gestoes"
  inflect.irregular "diretoria", "diretorias"
  inflect.irregular "ideia", "ideias"
  inflect.irregular "denuncia", "denuncias"
  inflect.irregular "acao", "acoes"
  inflect.irregular "tecnologia", "tecnologias"
  inflect.irregular "contribuicao", "contribuicoes"
  inflect.irregular "funcao", "funcoes"
  inflect.irregular "apresentacao", "apresentacoes"
  inflect.irregular "autor", "autores"
  inflect.irregular "avaliacao", "avaliacoes"
  inflect.irregular "categoria", "categorias" # senão /([ti])a$/ o deixa igual
  # palavras soltas (não o nome composto da tabela): a regra casa a ÚLTIMA
  # palavra, então "emblema_nivel" → "emblema_niveis" sai de graça, e
  # `resources :niveis` acha o helper singular certo
  inflect.irregular "conquista", "conquistas" # idem, por "-ta"
  inflect.irregular "nivel", "niveis"
end
