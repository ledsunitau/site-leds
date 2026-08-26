import { Controller } from "@hotwired/stimulus"

// Loja: carrinho (adicionar/remover, badge do FAB sem recarregar) e, no catálogo
// expandido (#LOJA2), os controles de filtro.
//
// O FILTRO em si é do servidor (produtos#todos): categoria e página são links,
// preço e promoção são inputs de um form GET. Aqui sobrou só o que é interação
// de tela — debounce da busca, min<=max do slider, espelhar os campos numéricos
// nos ranges. Saíram aplicar()/renderPaginacao()/irPara(), que peneiravam os
// cards já renderizados: a busca só via a página corrente e a grade inteira
// vinha do servidor para 8 itens ficarem visíveis.
const DEBOUNCE = 250

export default class extends Controller {
  static targets = [
    "badge", "busca", "form", "filtros", "tamanho", "qtd",
    "rangeMin", "rangeMax", "precoMin", "precoMax", "precoFill", "promo",
  ]
  static values = { produtoId: Number, nome: String, variante: String }

  connect() {
    this.varianteId = null
    if (this.hasPrecoFillTarget) this.atualizarFill()
  }

  disconnect() {
    clearTimeout(this.timer)
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

  // ---- Controles do filtro (#LOJA2) ----

  buscar() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.formTarget.requestSubmit(), DEBOUNCE)
  }

  submeterFiltros() {
    this.filtrosTarget.requestSubmit()
  }

  // Enquanto ARRASTA: só corrige min<=max e repinta a faixa. Nada de request —
  // é o evento `input`, que dispara a cada pixel. O request vem do `change`,
  // quando o dedo solta.
  arrastarPreco() {
    this.ordenarRanges()
    this.espelharNumeros()
    this.atualizarFill()
  }

  // Digitação nos campos numéricos: joga nos ranges e busca. `change` já é ao
  // sair do campo, então aqui submeter direto é o comportamento certo.
  precoPorNumero() {
    const teto = Number(this.rangeMaxTarget.max)
    this.rangeMinTarget.value = this.limitar(this.precoMinTarget.value, 0, teto)
    this.rangeMaxTarget.value = this.limitar(this.precoMaxTarget.value, 0, teto)
    this.ordenarRanges()
    this.espelharNumeros()
    this.atualizarFill()
    this.submeterFiltros()
  }

  // Os dois thumbs ficam sobrepostos; sem isto o "mínimo" pode passar o "máximo"
  // e a faixa vira negativa.
  ordenarRanges() {
    const lo = Number(this.rangeMinTarget.value)
    const hi = Number(this.rangeMaxTarget.value)
    if (lo > hi) {
      this.rangeMinTarget.value = hi
      this.rangeMaxTarget.value = lo
    }
  }

  espelharNumeros() {
    if (this.hasPrecoMinTarget) this.precoMinTarget.value = this.rangeMinTarget.value
    if (this.hasPrecoMaxTarget) this.precoMaxTarget.value = this.rangeMaxTarget.value
  }

  limitar(valor, min, max) {
    const n = parseFloat(valor)
    if (Number.isNaN(n)) return min
    return Math.min(max, Math.max(min, n))
  }

  atualizarFill() {
    if (!this.hasPrecoFillTarget || !this.hasRangeMaxTarget) return
    const teto = Number(this.rangeMaxTarget.max)
    if (!teto) return
    const pct = (v) => (Number(v) / teto) * 100
    this.precoFillTarget.style.left = `${pct(this.rangeMinTarget.value)}%`
    this.precoFillTarget.style.right = `${100 - pct(this.rangeMaxTarget.value)}%`
  }
}
