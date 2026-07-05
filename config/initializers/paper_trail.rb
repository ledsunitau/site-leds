# RF-NOV-07: o corpo dos posts é Action Text (tabela action_text_rich_texts)
# — sem versionar o RichText, o histórico perderia as mudanças no conteúdo em
# si, só registrando título/status.
#
# Allowlist explícita: rich text futuro em outro model NÃO ganha histórico
# de graça (versões guardam o corpo inteiro para sempre — quem precisar,
# adiciona aqui de propósito).
ActiveSupport.on_load(:action_text_rich_text) do
  has_paper_trail if: ->(rich_text) { rich_text.record_type == "Post" }
end
