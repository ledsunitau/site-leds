import { Controller } from "@hotwired/stimulus"

// Abas do "Meu perfil". Troca de painel client-side e sincroniza o hash da URL
// (pra abrir a aba certa depois de um redirect de ação, ex.: #loja).
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const hash = window.location.hash.replace("#", "")
    if (hash && this.tabTargets.some((t) => t.dataset.vista === hash)) this.abrir(hash)
  }

  mostrar(e) { this.abrir(e.currentTarget.dataset.vista) }

  abrir(vista) {
    this.tabTargets.forEach((t) => t.classList.toggle("active", t.dataset.vista === vista))
    this.panelTargets.forEach((p) => (p.hidden = p.dataset.vista !== vista))
    history.replaceState(null, "", `#${vista}`)
  }
}
