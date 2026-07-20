import { Controller } from "@hotwired/stimulus"

// Menu recolhível da navbar no mobile. Alterna a classe .open no menu e
// mantém aria-expanded em sincronia. close() é chamado ao clicar num link.
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    const open = this.menuTarget.classList.toggle("open")
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }

  close() {
    this.menuTarget.classList.remove("open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
