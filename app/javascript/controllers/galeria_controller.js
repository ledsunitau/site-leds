import { Controller } from "@hotwired/stimulus"

// Galeria do produto (#LOJA3): miniaturas trocam a foto principal; clicar na
// principal (ou no "+N") abre um lightbox/carrossel com todas as fotos e zoom.
export default class extends Controller {
  static targets = ["main", "lightbox", "lightboxImg", "contador"]
  static values = { fotos: Array }

  connect() {
    this.index = 0
    this.zoomed = false
    this.onKey = this.onKey.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    document.body.classList.remove("lightbox-aberto")
  }

  // Miniatura → troca a foto principal (inline, sem abrir o lightbox).
  trocar(e) {
    this.index = Number(e.currentTarget.dataset.index) || 0
    if (this.hasMainTarget) this.mainTarget.src = this.fotosValue[this.index]
    this.marcarThumb(this.index)
  }

  // Abre o lightbox no índice atual (ou no da miniatura clicada).
  abrir(e) {
    const idx = e?.currentTarget?.dataset?.index
    if (idx != null) this.index = Number(idx)
    this.render()
    this.lightboxTarget.hidden = false
    document.body.classList.add("lightbox-aberto")
    document.addEventListener("keydown", this.onKey)
  }

  fechar() {
    this.lightboxTarget.hidden = true
    this.setZoom(false)
    document.body.classList.remove("lightbox-aberto")
    document.removeEventListener("keydown", this.onKey)
  }

  // Fecha só se clicar no fundo (não na imagem/controles).
  fecharFora(e) {
    if (e.target === this.lightboxTarget) this.fechar()
  }

  anterior(e) {
    e?.stopPropagation()
    this.index = (this.index - 1 + this.fotosValue.length) % this.fotosValue.length
    this.render()
  }

  proximo(e) {
    e?.stopPropagation()
    this.index = (this.index + 1) % this.fotosValue.length
    this.render()
  }

  alternarZoom(e) {
    e?.stopPropagation()
    this.setZoom(!this.zoomed)
  }

  // --- helpers ---

  render() {
    if (this.hasLightboxImgTarget) {
      this.lightboxImgTarget.src = this.fotosValue[this.index]
      this.setZoom(false)
    }
    if (this.hasContadorTarget) {
      this.contadorTarget.textContent = `${this.index + 1} / ${this.fotosValue.length}`
    }
    this.marcarThumb(this.index)
  }

  setZoom(on) {
    this.zoomed = on
    if (this.hasLightboxImgTarget) this.lightboxImgTarget.classList.toggle("zoom", on)
  }

  marcarThumb(i) {
    this.element
      .querySelectorAll(".galeria-thumb")
      .forEach((t) => t.classList.toggle("ativa", Number(t.dataset.index) === i))
  }

  onKey(e) {
    if (e.key === "Escape") this.fechar()
    else if (e.key === "ArrowLeft") this.anterior()
    else if (e.key === "ArrowRight") this.proximo()
  }
}
