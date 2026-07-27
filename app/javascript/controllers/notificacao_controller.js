import { Controller } from "@hotwired/stimulus"

// Marcar notificações como lidas sem recarregar (fetch). Sem JS, o button_to
// cai no fallback HTML (redirect) do controller.
export default class extends Controller {
  static targets = ["item"]

  ler(e) {
    e.preventDefault()
    const form = e.currentTarget.closest("form")
    const item = e.currentTarget.closest(".notif-item")
    this.post(form.action).then(() => {
      item?.classList.remove("nao-lida")
      e.currentTarget.remove()
      this.ajustarBadge(-1)
    })
  }

  lerTodas(e) {
    e.preventDefault()
    const form = e.currentTarget.closest("form")
    this.post(form.action).then(() => {
      this.itemTargets.forEach((li) => li.classList.remove("nao-lida"))
      this.element.querySelectorAll(".notif-ler").forEach((b) => b.remove())
      this.ajustarBadge(0)
      e.currentTarget.remove()
    })
  }

  post(url) {
    return fetch(url, {
      method: "POST",
      headers: { "X-CSRF-Token": this.token, Accept: "application/json" }
    }).catch(() => {})
  }

  get token() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  // delta = -1 decrementa; 0 zera. Remove o badge quando chega a zero.
  ajustarBadge(delta) {
    const badge = document.querySelector(".perfil-badge")
    if (!badge) return
    const n = delta === 0 ? 0 : Math.max(0, Number(badge.textContent) - 1)
    if (n === 0) badge.remove()
    else badge.textContent = String(n)
  }
}
