import { Controller } from "@hotwired/stimulus"

// Grid de Novidades: filtro por tipo (chips) + busca por título (lupa) +
// paginação (6 por página). Tudo client-side sobre os cards do banco.
export default class extends Controller {
  static targets = ["chip", "card", "busca", "empty", "paginacao"]
  static values = { porPagina: { type: Number, default: 6 } }

  connect() {
    this.tipo = "todos"
    this.termo = ""
    this.pagina = 1
    this.aplicar()
  }

  filtrar(e) {
    this.tipo = e.currentTarget.dataset.tipo
    this.chipTargets.forEach((c) => c.classList.toggle("active", c === e.currentTarget))
    this.pagina = 1
    this.aplicar()
  }

  toggleBusca() {
    const input = this.buscaTarget
    input.hidden = !input.hidden
    if (!input.hidden) {
      input.focus()
    } else {
      input.value = ""
      this.termo = ""
      this.pagina = 1
      this.aplicar()
    }
  }

  buscar() {
    this.termo = this.buscaTarget.value.trim().toLowerCase()
    this.pagina = 1
    this.aplicar()
  }

  irPara(e) {
    this.pagina = Number(e.currentTarget.dataset.pagina)
    this.aplicar()
  }

  aplicar() {
    const filtrados = this.cardTargets.filter(
      (c) =>
        (this.tipo === "todos" || c.dataset.tipo === this.tipo) &&
        (this.termo === "" || c.dataset.nome.includes(this.termo))
    )
    const paginas = Math.max(1, Math.ceil(filtrados.length / this.porPaginaValue))
    if (this.pagina > paginas) this.pagina = paginas

    const inicio = (this.pagina - 1) * this.porPaginaValue
    const visiveis = filtrados.slice(inicio, inicio + this.porPaginaValue)
    this.cardTargets.forEach((c) => (c.hidden = true))
    visiveis.forEach((c) => (c.hidden = false))

    if (this.hasEmptyTarget) this.emptyTarget.hidden = filtrados.length > 0
    this.renderPaginacao(paginas)
  }

  // Botões de página construídos via DOM (sem innerHTML): só números.
  renderPaginacao(paginas) {
    if (!this.hasPaginacaoTarget) return
    this.paginacaoTarget.replaceChildren()
    if (paginas <= 1) return

    for (let p = 1; p <= paginas; p++) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "novidades-pag"
      if (p === this.pagina) btn.classList.add("active")
      btn.dataset.pagina = String(p)
      btn.dataset.action = "novidades#irPara"
      btn.textContent = String(p)
      this.paginacaoTarget.appendChild(btn)
    }
  }
}
