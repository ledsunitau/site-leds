import { Controller } from "@hotwired/stimulus"

// Avaliações (#LOJA4): star-picker do formulário (define a nota escondida) e
// paginação client-side dos cards de avaliação.
export default class extends Controller {
  static targets = ["lista", "paginacao", "picker", "nota"]
  static values = { porPagina: { type: Number, default: 4 } }

  connect() {
    this.pagina = 1
    if (this.hasListaTarget) this.aplicar()
  }

  // ---- Star picker ----

  escolher(e) {
    const nota = Number(e.currentTarget.dataset.nota)
    if (this.hasNotaTarget) this.notaTarget.value = nota
    this.pickerTarget
      .querySelectorAll(".star-btn")
      .forEach((s, i) => s.classList.toggle("on", i < nota))
  }

  // ---- Paginação dos cards ----

  cards() {
    return Array.from(this.listaTarget.querySelectorAll(".avaliacao-card"))
  }

  irPara(e) {
    this.pagina = Number(e.currentTarget.dataset.pagina)
    this.aplicar()
  }

  aplicar() {
    const cards = this.cards()
    const paginas = Math.max(1, Math.ceil(cards.length / this.porPaginaValue))
    if (this.pagina > paginas) this.pagina = paginas

    const inicio = (this.pagina - 1) * this.porPaginaValue
    cards.forEach((c, i) => (c.hidden = i < inicio || i >= inicio + this.porPaginaValue))
    this.renderPaginacao(paginas)
  }

  renderPaginacao(paginas) {
    if (!this.hasPaginacaoTarget) return
    this.paginacaoTarget.replaceChildren()
    if (paginas <= 1) return

    for (let p = 1; p <= paginas; p++) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "loja-pag"
      if (p === this.pagina) btn.classList.add("active")
      btn.dataset.pagina = String(p)
      btn.dataset.action = "avaliacao#irPara"
      btn.textContent = String(p)
      this.paginacaoTarget.appendChild(btn)
    }
  }
}
