import { Controller } from "@hotwired/stimulus"

// Coleta de comportamento (RN-14) que abastece as métricas da gestão.
// Fica no <body> do layout público. O servidor revalida o consentimento de
// qualquer jeito (CookieConsent.analytics_permitido?); o teste no localStorage
// aqui só evita a requisição inútil de quem recusou.
//
// Envia em LOTE, nunca por evento: o throttle de /events conta requests
// (60/min/ip) e o campus inteiro divide um NAT.
const KEY = "leds_cookie_consent"
const LIMITE = 50 // espelha EventsController::LIMITE_LOTE — nada além disso é gravado

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.fila = []
    this.descarregar = () => this.enviar()

    // O consentimento é tri-estado: "analytics" (aceitou), "essential"
    // (recusou) ou ausente (ainda não decidiu). Só o primeiro coleta.
    if (!this.permitido()) return

    this.registrar("pageview")

    // Turbo Drive não recarrega a página, então "pagehide" só dispara ao sair
    // do site — sem turbo:before-visit os eventos de navegação interna morreriam
    // na fila. visibilitychange cobre o mobile, que costuma pular o pagehide.
    addEventListener("pagehide", this.descarregar)
    addEventListener("turbo:before-visit", this.descarregar)
    this.aoEsconder = () => { if (document.visibilityState === "hidden") this.enviar() }
    addEventListener("visibilitychange", this.aoEsconder)
  }

  disconnect() {
    if (!this.descarregar) return
    this.enviar()
    removeEventListener("pagehide", this.descarregar)
    removeEventListener("turbo:before-visit", this.descarregar)
    removeEventListener("visibilitychange", this.aoEsconder)
  }

  // data-action="analytics#rastrear" + data-evento="produto_view" em qualquer
  // elemento. data-meta (JSON) é opcional e vai no metadata do evento.
  rastrear(e) {
    const el = e.currentTarget
    this.registrar(el.dataset.evento, this.meta(el.dataset.meta))
  }

  registrar(nome, metadata = {}) {
    if (!nome || !this.permitido() || this.fila.length >= LIMITE) return
    this.fila.push({ nome, rota: location.pathname, referrer: document.referrer || null, metadata })
  }

  enviar() {
    if (!this.fila.length) return
    const corpo = JSON.stringify({ events: this.fila.splice(0, LIMITE) })

    // sendBeacon manda text/plain por padrão e o Rails não parseia isso como
    // JSON — params[:events] viria nil. O Blob carrega o Content-Type certo.
    const pacote = new Blob([corpo], { type: "application/json" })
    if (!navigator.sendBeacon || !navigator.sendBeacon(this.urlValue, pacote)) {
      fetch(this.urlValue, {
        method: "POST", body: corpo, keepalive: true,
        headers: { "Content-Type": "application/json" }
      }).catch(() => {})
    }
  }

  permitido() {
    try { return localStorage.getItem(KEY) === "analytics" } catch (_) { return false }
  }

  meta(bruto) {
    if (!bruto) return {}
    try { return JSON.parse(bruto) } catch (_) { return {} }
  }
}
