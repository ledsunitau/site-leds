import { Controller } from "@hotwired/stimulus"

// Página de Ações: só a lupa e o debounce da busca.
//
// O filtro por tipo e a paginação são LINKS resolvidos no servidor (ver
// acoes#index) — o Turbo troca o frame sozinho, sem JS nenhum. O que existia
// aqui antes (aplicar/renderPaginacao sobre os cards já renderizados) filtrava
// só o que estava na tela: buscar por algo fora da primeira leva devolvia
// "nenhuma ação encontrada" com o item existindo no banco.
const DEBOUNCE = 250

export default class extends Controller {
  static targets = ["busca", "form"]

  disconnect() {
    clearTimeout(this.timer)
  }

  toggleBusca() {
    const input = this.buscaTarget
    input.hidden = !input.hidden
    if (!input.hidden) {
      input.focus()
      return
    }
    // Fechar a lupa com termo digitado limpa a busca — e como o termo vem da
    // URL, limpar exige ir ao servidor de novo.
    if (input.value !== "") {
      input.value = ""
      this.submeter()
    }
  }

  // Debounce: sem ele cada tecla vira um request de frame.
  buscar() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submeter(), DEBOUNCE)
  }

  submeter() {
    this.formTarget.requestSubmit()
  }
}
