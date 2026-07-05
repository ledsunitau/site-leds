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
#   - "-ia" é tratado como plural latino e fica IGUAL (diretoria -> "diretoria",
#     regra default /([ti])a$/ para criteria/media).
# Toda branch que criar tabela com nome em português DEVE conferir o plural
# aqui (pendentes: ideia, denuncia, apresentacao, autor->autores,
# item_pedido->itens_pedido...).
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "gestao", "gestoes"
  inflect.irregular "diretoria", "diretorias"
  inflect.irregular "acao", "acoes"
  inflect.irregular "tecnologia", "tecnologias"
  inflect.irregular "contribuicao", "contribuicoes"
end
