# Dois modos de editor no post (RF-NOV-04): o rico (Trix/Action Text, que já
# existia) e markdown.
#
# corpo_markdown guarda o FONTE; o corpo (Action Text) continua guardando o HTML
# renderizado. Assim página pública, cards, JSON, PaperTrail e o anúncio no
# Discord seguem lendo `corpo` sem saber que existem dois modos — só o
# formulário sabe.
#
# default 'rico': todo post que já existe foi escrito no Trix.
class ModoMarkdownNosPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :formato, :string, null: false, default: "rico"
    add_column :posts, :corpo_markdown, :text

    add_check_constraint :posts, "formato IN ('rico','markdown')",
                         name: "posts_formato_check"
  end
end
