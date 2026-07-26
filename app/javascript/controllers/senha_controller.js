import { Controller } from "@hotwired/stimulus"

// Mostrar/ocultar senha. Oculta = olho fechado; visível = olho aberto.
export default class extends Controller {
  static targets = ["input", "aberto", "fechado"]

  toggle() {
    const revelar = this.inputTarget.type === "password"
    this.inputTarget.type = revelar ? "text" : "password"
    // toggleAttribute (não .hidden): SVGElement não reflete a propriedade .hidden,
    // então setar .hidden num <svg> não mexe no atributo nem no render.
    this.abertoTarget.toggleAttribute("hidden", !revelar)
    this.fechadoTarget.toggleAttribute("hidden", revelar)
  }
}
