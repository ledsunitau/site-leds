import { Controller } from "@hotwired/stimulus"

// Loja: adicionar/remover do carrinho (atualiza o badge do FAB sem recarregar),
// e — no catálogo expandido (#LOJA2) — filtro por categoria + paginação, tudo
// client-side sobre os .produto-card do banco.
export default class extends Controller {
  static targets = [
    "badge", "grade", "categoria", "vazio", "paginacao", "tamanho", "qtd", "busca",
    "rangeMin", "rangeMax", "precoMin", "precoMax", "precoFill", "promo",
  ]
  static values = {
    produtoId: Number, nome: String, variante: String, teto: Number,
    porPagina: { type: Number, default: 8 },
  }

  connect() {
    this.varianteId = null
    if (this.hasGradeTarget) {
      this.cat = ""
      this.termo = ""
      this.pMin = 0
      this.pMax = this.hasTetoValue ? this.tetoValue : Infinity
      this.promoOnly = false
      this.pagina = 1
      this.atualizarFill()
      this.aplicar()
    }
  }

  // ---- Carrinho ----

  adicionar(e) {
    this.enviarItem(
      { produto_id: e.params.produto, variante_id: e.params.variante || null, quantidade: 1 },
      e.params.nome
    )
  }

  escolherTamanho(e) {
    this.varianteId = e.currentTarget.dataset.variante
    this.tamanhoTargets.forEach((t) => t.classList.toggle("ativo", t === e.currentTarget))
  }

  menos() { this.ajustarQtd(-1) }
  mais() { this.ajustarQtd(1) }

  ajustarQtd(delta) {
    if (!this.hasQtdTarget) return
    const atual = Math.max(1, (parseInt(this.qtdTarget.value, 10) || 1) + delta)
    this.qtdTarget.value = atual
  }

  adicionarDetalhe() {
    if (this.hasTamanhoTarget && !this.varianteId) {
      this.toast("Escolha um tamanho.", "alert")
      return false
    }
    // seleção do usuário, ou a variante única do produto ("Único")
    const variante = this.varianteId || (this.hasVarianteValue ? this.varianteValue : null)
    const qtd = this.hasQtdTarget ? Math.max(1, parseInt(this.qtdTarget.value, 10) || 1) : 1
    return this.enviarItem({
      produto_id: this.produtoIdValue,
      variante_id: variante,
      quantidade: qtd,
    }, this.hasNomeValue ? this.nomeValue : null)
  }

  async comprarAgora() {
    const ok = await this.adicionarDetalhe()
    if (ok) window.location.href = "/carrinho"
  }

  async enviarItem(item, nome = null) {
    try {
      const resp = await fetch("/carrinho/itens", {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify({ item }),
      })
      const dados = await resp.json().catch(() => ({}))
      if (!resp.ok) {
        this.toast((dados.errors && dados.errors[0]) || "Não foi possível adicionar ao carrinho.", "alert")
        return false
      }
      this.atualizarBadge(dados.total_itens)
      this.toast(
        nome
          ? `O produto "${nome}" foi adicionado ao carrinho com sucesso ✓`
          : "Produto adicionado ao carrinho com sucesso ✓"
      )
      return true
    } catch {
      this.toast("Falha de conexão. Tente de novo.", "alert")
      return false
    }
  }

  // Toast reaproveitando o estilo do flash global (.flash-stack/.flash-toast).
  toast(msg, tipo = "notice") {
    let stack = document.querySelector(".flash-stack")
    if (!stack) {
      stack = document.createElement("div")
      stack.className = "flash-stack"
      document.body.appendChild(stack)
    }
    const el = document.createElement("div")
    el.className = `flash-toast ${tipo}`
    el.setAttribute("role", "status")
    el.textContent = msg
    stack.appendChild(el)
    setTimeout(() => {
      el.classList.add("out")
      setTimeout(() => el.remove(), 300)
    }, 2200)
  }

  async remover(e) {
    const id = e.params.item
    const resp = await fetch(`/carrinho/itens/${id}`, { method: "DELETE", headers: this.headers() })
    if (resp.ok) window.location.reload()
  }

  atualizarBadge(total) {
    if (total == null) return
    this.badgeTargets.forEach((b) => {
      b.textContent = String(total)
      b.hidden = total <= 0
    })
  }

  headers() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    return { "Content-Type": "application/json", "X-CSRF-Token": token || "", Accept: "application/json" }
  }

  // ---- Filtro + paginação (#LOJA2) ----

  filtrarCategoria(e) {
    this.cat = e.currentTarget.dataset.cat
    this.categoriaTargets.forEach((c) => c.classList.toggle("active", c === e.currentTarget))
    this.pagina = 1
    this.aplicar()
  }

  buscar() {
    this.termo = this.buscaTarget.value.trim().toLowerCase()
    this.pagina = 1
    this.aplicar()
  }

  // Preço pelos sliders (dois thumbs sobrepostos; garante min <= max).
  faixaPrecoSlider() {
    let lo = Number(this.rangeMinTarget.value)
    let hi = Number(this.rangeMaxTarget.value)
    if (lo > hi) [lo, hi] = [hi, lo]
    this.aplicarFaixa(lo, hi)
  }

  // Preço pelos inputs numéricos (digitação manual).
  faixaPrecoNumero() {
    const teto = this.hasTetoValue ? this.tetoValue : Infinity
    let lo = this.limpar(this.precoMinTarget.value, 0, teto)
    let hi = this.limpar(this.precoMaxTarget.value, 0, teto)
    if (lo > hi) [lo, hi] = [hi, lo]
    this.aplicarFaixa(lo, hi)
  }

  aplicarFaixa(lo, hi) {
    this.pMin = lo
    this.pMax = hi
    if (this.hasRangeMinTarget) this.rangeMinTarget.value = lo
    if (this.hasRangeMaxTarget) this.rangeMaxTarget.value = hi
    if (this.hasPrecoMinTarget) this.precoMinTarget.value = lo
    if (this.hasPrecoMaxTarget) this.precoMaxTarget.value = hi
    this.atualizarFill()
    this.pagina = 1
    this.aplicar()
  }

  filtrarPromo() {
    this.promoOnly = this.promoTarget.checked
    this.pagina = 1
    this.aplicar()
  }

  limpar(valor, min, max) {
    const n = parseFloat(valor)
    if (Number.isNaN(n)) return min
    return Math.min(max, Math.max(min, n))
  }

  atualizarFill() {
    if (!this.hasPrecoFillTarget || !this.hasTetoValue || this.tetoValue <= 0) return
    const pct = (v) => (v / this.tetoValue) * 100
    this.precoFillTarget.style.left = `${pct(this.pMin)}%`
    this.precoFillTarget.style.right = `${100 - pct(this.pMax)}%`
  }

  limparFiltro() {
    this.termo = ""
    if (this.hasBuscaTarget) this.buscaTarget.value = ""
    if (this.hasPromoTarget) this.promoTarget.checked = false
    this.promoOnly = false
    this.aplicarFaixa(0, this.hasTetoValue ? this.tetoValue : Infinity)
    const todas = this.categoriaTargets.find((c) => c.dataset.cat === "")
    if (todas) todas.click()
  }

  irPara(e) {
    this.pagina = Number(e.currentTarget.dataset.pagina)
    this.aplicar()
  }

  cards() {
    return Array.from(this.gradeTarget.querySelectorAll(".produto-card"))
  }

  aplicar() {
    const filtrados = this.cards().filter((c) => {
      const preco = parseFloat(c.dataset.preco) || 0
      return (
        (this.cat === "" || c.dataset.categoria === this.cat) &&
        (!this.termo || (c.dataset.nome || "").includes(this.termo)) &&
        preco >= this.pMin &&
        preco <= this.pMax &&
        (!this.promoOnly || c.dataset.promo === "true")
      )
    })
    const paginas = Math.max(1, Math.ceil(filtrados.length / this.porPaginaValue))
    if (this.pagina > paginas) this.pagina = paginas

    const inicio = (this.pagina - 1) * this.porPaginaValue
    const visiveis = filtrados.slice(inicio, inicio + this.porPaginaValue)
    this.cards().forEach((c) => (c.hidden = true))
    visiveis.forEach((c) => (c.hidden = false))

    if (this.hasVazioTarget) this.vazioTarget.hidden = filtrados.length > 0
    this.renderPaginacao(paginas)
  }

  renderPaginacao(paginas) {
    if (!this.hasPaginacaoTarget) return
    this.paginacaoTarget.replaceChildren()
    if (paginas <= 1) return

    for (let p = 1; p <= paginas; p++) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "loja-pag"
      if (p === this.pagina) btn.classList.add("active")
      btn.dataset.pagina = String(p)
      btn.dataset.action = "loja#irPara"
      btn.textContent = String(p)
      this.paginacaoTarget.appendChild(btn)
    }
  }
}
