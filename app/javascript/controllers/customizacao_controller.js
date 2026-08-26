import { Controller } from "@hotwired/stimulus"

// Prévia ao vivo da aba Customização: o cartão no topo mostra como a pessoa vai
// aparecer no site, e repinta a cada escolha — antes de salvar.
//
// A seleção em si é <input type=radio> puro; este controller só reflete. Se o
// JS não carregar, escolher e salvar continua funcionando (só sem a prévia).
export default class extends Controller {
  static targets = ["nome", "avatar", "previaDestaque", "previaSecundario"]

  connect() {
    for (const alvo of ["destaque", "secundario", "nome", "halo"]) this.aplicar(alvo)
  }

  repintar(evento) {
    this.aplicar(evento.params.alvo)
  }

  aplicar(alvo) {
    const escolhido = this.marcado(alvo)
    if (alvo === "nome") this.pintar(this.nomeTarget, escolhido, "nome-emblema")
    else if (alvo === "halo") this.pintar(this.avatarTarget, escolhido, "avatar-anel")
    else this.trocarIcone(alvo, escolhido)
  }

  // Pintura: as duas variáveis que o CSS consome + a classe do movimento. Os
  // valores vêm de data-attributes que o servidor escreveu, não de input livre.
  pintar(elemento, radio, classeBase) {
    elemento.classList.remove(classeBase, "cosm-parado", "cosm-varredura", "cosm-fluxo", "cosm-pulso")
    elemento.style.removeProperty("--emblema-grad")
    elemento.style.removeProperty("--emblema-vel")
    if (!radio || !radio.dataset.grad) return

    elemento.style.setProperty("--emblema-grad", radio.dataset.grad)
    elemento.style.setProperty("--emblema-vel", radio.dataset.vel)
    elemento.classList.add(classeBase, `cosm-${radio.dataset.mov}`)
  }

  // Ícone: CLONA o nó que o servidor já renderizou (e já sanitizou) dentro da
  // opção. Nada de innerHTML com markup de banco — cloneNode não interpreta
  // string nenhuma.
  trocarIcone(alvo, radio) {
    const destino = alvo === "destaque" ? this.previaDestaqueTarget : this.previaSecundarioTarget
    const icone = radio?.closest(".custom-opcao")?.querySelector(".emblema")
    if (icone) destino.replaceChildren(icone.cloneNode(true))
    else destino.replaceChildren() // sem argumento: esvazia de verdade
  }

  marcado(alvo) {
    return this.element.querySelector(`input[data-customizacao-alvo-param="${alvo}"]:checked`)
  }
}
