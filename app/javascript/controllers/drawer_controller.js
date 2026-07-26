import { Controller } from "@hotwired/stimulus"

// Menu lateral da conta. Fica no <body> (fora da navbar, que tem backdrop-filter
// e viraria o bloco de contenção do position:fixed). Abre/fecha alternando
// .open no root; fecha no Esc, no overlay, num link ou no ×.
export default class extends Controller {
  static targets = ["root"]

  connect() {
    this._esc = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._esc)
  }

  disconnect() {
    document.removeEventListener("keydown", this._esc)
    document.body.classList.remove("no-scroll")
  }

  open() { this.toggle(true) }
  close() { this.toggle(false) }

  toggle(mostrar) {
    if (!this.hasRootTarget) return
    this.rootTarget.classList.toggle("open", mostrar)
    document.body.classList.toggle("no-scroll", mostrar)
  }
}
