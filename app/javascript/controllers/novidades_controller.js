import { Controller } from "@hotwired/stimulus"

// Grid de Novidades: só a lupa e o debounce da busca.
//
// Filtro por tipo e paginação são links resolvidos no servidor (posts#index);
// o Turbo troca o frame. Saíram daqui aplicar()/renderPaginacao()/irPara(),
// que filtravam e paginavam sobre os cards já renderizados — a busca só
// enxergava a página corrente.
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
    if (input.value !== "") {
      input.value = ""
      this.submeter()
    }
  }

  buscar() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submeter(), DEBOUNCE)
  }

  submeter() {
    this.formTarget.requestSubmit()
  }
}
