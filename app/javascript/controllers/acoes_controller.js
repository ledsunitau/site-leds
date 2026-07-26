import { Controller } from "@hotwired/stimulus"

// Página de Ações: filtro por tipo (chips) + busca por nome (lupa).
// Tudo client-side sobre os cards já renderizados do banco.
export default class extends Controller {
  static targets = ["chip", "card", "busca", "empty", "list", "end"]

  connect() {
    this.tipo = "todos"
    this.termo = ""
  }

  filtrar(e) {
    this.tipo = e.currentTarget.dataset.tipo
    this.chipTargets.forEach((c) => c.classList.toggle("active", c === e.currentTarget))
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
      this.aplicar()
    }
  }

  buscar() {
    this.termo = this.buscaTarget.value.trim().toLowerCase()
    this.aplicar()
  }

  aplicar() {
    let visiveis = 0
    this.cardTargets.forEach((card) => {
      const okTipo = this.tipo === "todos" || card.dataset.tipo === this.tipo
      const okNome = this.termo === "" || card.dataset.nome.includes(this.termo)
      const mostra = okTipo && okNome
      card.hidden = !mostra
      if (mostra) visiveis++
    })
    this.emptyTarget.hidden = visiveis > 0
    if (this.hasEndTarget) this.endTarget.hidden = visiveis === 0
  }
}
