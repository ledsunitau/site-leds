import { Controller } from "@hotwired/stimulus"

// Portal de ideias: pré-filtra os tipos por grupo (vindo dos botões da home,
// ?grupo=eventos|projetos), depois LIMPA o param da URL — assim um hard refresh
// mostra os 4 tipos de novo. "ver todos os tipos" também mostra os 4.
export default class extends Controller {
  static targets = ["card", "verTodos"]
  static values = { grupo: String }

  connect() {
    if (!this.grupoValue) return
    this.filtrar(this.grupoValue)
    const url = new URL(window.location.href)
    if (url.searchParams.has("grupo")) {
      url.searchParams.delete("grupo")
      history.replaceState(null, "", url.pathname + url.search + url.hash)
    }
  }

  filtrar(grupo) {
    this.cardTargets.forEach((card) => this.toggleCard(card, card.dataset.grupo !== grupo))
    if (this.hasVerTodosTarget) this.verTodosTarget.hidden = false
  }

  verTodos() {
    this.cardTargets.forEach((card) => this.toggleCard(card, false))
    if (this.hasVerTodosTarget) this.verTodosTarget.hidden = true
  }

  // Esconde e DESABILITA o rádio do card oculto: um rádio required escondido
  // travaria o submit ("invalid form control not focusable").
  toggleCard(card, oculto) {
    card.hidden = oculto
    const radio = card.querySelector("input[type=radio]")
    if (radio) radio.disabled = oculto
  }
}
