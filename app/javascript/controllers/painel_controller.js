import { Controller } from "@hotwired/stimulus"

// Casca do painel de gestão: sidebar no mobile e sub-abas (mesma lógica do
// perfil, com o hash da URL para sobreviver a redirect de ação).
export default class extends Controller {
  static targets = ["side", "tab", "panel"]

  connect() {
    const hash = window.location.hash.replace("#", "")
    if (hash && this.tabTargets.some((t) => t.dataset.vista === hash)) this.abrir(hash)
  }

  abrirMenu() { this.element.classList.add("menu-aberto") }
  fecharMenu() { this.element.classList.remove("menu-aberto") }

  mostrar(e) { this.abrir(e.currentTarget.dataset.vista) }

  abrir(vista) {
    this.tabTargets.forEach((t) => t.classList.toggle("active", t.dataset.vista === vista))
    this.panelTargets.forEach((p) => (p.hidden = p.dataset.vista !== vista))
    history.replaceState(null, "", `#${vista}`)
  }
}
