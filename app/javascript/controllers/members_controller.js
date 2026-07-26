import { Controller } from "@hotwired/stimulus"

// Página de Membros: alterna entre "Rede de membros" e "Genograma" e filtra os
// cards por grupo (chips). Tudo client-side sobre o que já veio do banco.
export default class extends Controller {
  static targets = ["tab", "panel", "chip", "card", "empty", "busca"]

  connect() {
    this.grupo = "todos"
    this.termo = ""
  }

  // Troca a vista (rede ⇄ genograma).
  mostrar(e) {
    const vista = e.currentTarget.dataset.vista
    this.tabTargets.forEach((t) => t.classList.toggle("active", t === e.currentTarget))
    this.panelTargets.forEach((p) => (p.hidden = p.dataset.vista !== vista))
  }

  // Filtra os cards pelo grupo do chip.
  filtrar(e) {
    this.grupo = e.currentTarget.dataset.grupo
    this.chipTargets.forEach((c) => c.classList.toggle("active", c === e.currentTarget))
    this.aplicar()
  }

  // Mostra/esconde o campo de busca (lupa).
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

  // Grupo (chip) + busca por nome combinados.
  aplicar() {
    let visiveis = 0
    this.cardTargets.forEach((card) => {
      const okGrupo = this.grupo === "todos" || card.dataset.grupo === this.grupo
      const okNome = this.termo === "" || card.dataset.nome.includes(this.termo)
      const mostra = okGrupo && okNome
      card.hidden = !mostra
      if (mostra) visiveis++
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visiveis > 0
  }
}
