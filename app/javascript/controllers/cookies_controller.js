import { Controller } from "@hotwired/stimulus"

// Banner de consentimento de cookies (RNF-04/05). Mostra só se ainda não houve
// decisão (flag no localStorage) e grava a escolha em /consents (RN-14).
const KEY = "leds_cookie_consent"

export default class extends Controller {
  static values = { url: String }

  connect() {
    if (!this.decidido()) this.element.hidden = false
  }

  aceitar() { this.enviar(true) }
  recusar() { this.enviar(false) }

  enviar(analytics) {
    // Otimista: registra a escolha e esconde JÁ (não trava esperando a rede);
    // a gravação vai em background. Evita cliques repetidos → throttle 429.
    try { localStorage.setItem(KEY, analytics ? "analytics" : "essential") } catch (_) {}
    this.element.hidden = true
    fetch(this.urlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ analytics, marketing: false })
    }).catch(() => {})
  }

  decidido() {
    try { return !!localStorage.getItem(KEY) } catch (_) { return false }
  }
}
