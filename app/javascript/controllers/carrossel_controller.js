import { Controller } from "@hotwired/stimulus"

// Carrossel genérico (reusável): translada a trilha e sincroniza os dots.
// Avança sozinho a cada `interval` ms e também aceita ARRASTE (pointer/touch)
// para trocar de slide na mão. Usado nas Novidades.
export default class extends Controller {
  static targets = ["viewport", "track", "slide", "dot"]
  static values = { index: { type: Number, default: 0 }, interval: { type: Number, default: 6000 } }

  connect() {
    this.update()
    if (this.slideTargets.length > 1 && this.intervalValue > 0) this.start()
  }

  disconnect() {
    this.stop()
  }

  start() { this.timer = setInterval(() => this.next(), this.intervalValue) }
  stop() { if (this.timer) clearInterval(this.timer) }
  restart() { this.stop(); if (this.intervalValue > 0) this.start() }

  next() { this.go(this.wrap(this.indexValue + 1)) }
  prev() { this.go(this.wrap(this.indexValue - 1)) }
  wrap(i) { const n = this.slideTargets.length; return (i % n + n) % n }

  goTo(e) {
    this.go(Number(e.currentTarget.dataset.index))
    this.restart()
  }

  go(i) {
    this.indexValue = i
    this.update()
  }

  update() {
    if (this.hasTrackTarget) this.trackTarget.style.transform = `translateX(-${this.indexValue * 100}%)`
    this.dotTargets.forEach((d, j) => d.classList.toggle("active", j === this.indexValue))
  }

  // --- arraste ---

  dragStart(e) {
    if (this.slideTargets.length < 2) return
    this.dragging = true
    this.moved = false
    this.startX = e.clientX
    this.deltaX = 0
    this.stop() // pausa o autoplay durante o arraste
    if (this.hasTrackTarget) this.trackTarget.style.transition = "none"
    if (this.hasViewportTarget && e.pointerId != null) {
      this.viewportTarget.setPointerCapture?.(e.pointerId)
    }
  }

  dragMove(e) {
    if (!this.dragging) return
    this.deltaX = e.clientX - this.startX
    if (Math.abs(this.deltaX) > 6) this.moved = true
    const largura = this.trackTarget.offsetWidth || 1
    const pct = (this.deltaX / largura) * 100
    this.trackTarget.style.transform = `translateX(calc(-${this.indexValue * 100}% + ${pct}%))`
  }

  dragEnd() {
    if (!this.dragging) return
    this.dragging = false
    if (this.hasTrackTarget) this.trackTarget.style.transition = ""

    const limiar = (this.trackTarget.offsetWidth || 1) * 0.15
    if (this.deltaX < -limiar) this.next()
    else if (this.deltaX > limiar) this.prev()
    else this.update() // não passou do limiar: volta pro slide atual

    // arrastou de verdade: engole o clique que viria a seguir (senão navega)
    if (this.moved) this.suppressClick = true
    this.restart()
  }

  // Cancela a navegação do link quando o "clique" foi na verdade um arraste.
  onClick(e) {
    if (this.suppressClick) {
      e.preventDefault()
      this.suppressClick = false
    }
  }

  // Impede o drag NATIVO do link/imagem (o "fantasma" da URL), que senão
  // engoliria os pointermove e travaria o arraste do carrossel.
  noNativeDrag(e) {
    e.preventDefault()
  }
}
