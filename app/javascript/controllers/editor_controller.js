import { Controller } from "@hotwired/stimulus"
import "trix"
import "@rails/actiontext"

// Editor de texto rico dos posts. O Trix e o Action Text só entram na página
// que tem editor — importar aqui (e não no application.js) mantém o site
// público sem o custo do editor.
//
// O Trix registra <trix-editor> ao ser importado; este controller só ajusta a
// barra de ferramentas para o que a liga usa de fato.
export default class extends Controller {
  connect() {
    // Trix aceita cabeçalho só como "heading1". Sem isso a barra oferece um
    // botão de título que gera markup que o resto do site não estiliza.
    addEventListener("trix-initialize", this.limparBarra, { once: true })
  }

  limparBarra(e) {
    const barra = e.target.toolbarElement
    if (!barra) return
    // arquivo/anexo: o upload direto exige Active Storage no formulário e a
    // thumbnail já tem campo próprio — deixar o botão aqui só gera erro mudo.
    barra.querySelector("[data-trix-button-group=file-tools]")?.remove()
  }
}
