import { Controller } from "@hotwired/stimulus"

// Flash global: some sozinho depois de alguns segundos e fecha no clique.
export default class extends Controller {
  static targets = ["toast"]

  connect() {
    this.timers = this.toastTargets.map((t) => setTimeout(() => this.dismiss(t), 6000))
  }

  disconnect() {
    (this.timers || []).forEach(clearTimeout)
  }

  close(e) {
    this.dismiss(e.currentTarget.closest(".flash-toast"))
  }

  dismiss(el) {
    if (!el) return
    el.classList.add("out")
    setTimeout(() => el.remove(), 250)
  }
}
