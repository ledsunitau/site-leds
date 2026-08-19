import { Controller } from "@hotwired/stimulus"

// Linhas adicionáveis/removíveis das coleções aninhadas da ação
// (contribuições, autores, convidados, apresentações...).
//
// O índice só precisa ser único DENTRO do formulário — o servidor normaliza o
// hash indexado para lista e descarta linha em branco. Por isso um contador
// crescente basta: não há tentativa de casar índice com registro do banco.
export default class extends Controller {
  static targets = ["grupo", "linhas", "molde", "vazio"]

  adicionar(e) {
    const grupo = e.currentTarget.closest("[data-colecao-target='grupo']")
    const molde = grupo.querySelector("template")
    const linhas = grupo.querySelector("[data-colecao-target='linhas']")

    // conta o que já existe + o que já foi adicionado nesta sessão, para dois
    // cliques seguidos não gerarem o mesmo índice (que sobrescreveria a linha)
    grupo.dataset.proximo = String(Number(grupo.dataset.proximo || linhas.children.length) + 1)
    const indice = Number(grupo.dataset.proximo) + 1000

    const html = molde.innerHTML.replaceAll("__IDX__", String(indice))
    linhas.insertAdjacentHTML("beforeend", html)
    this.atualizarVazio(grupo)
  }

  remover(e) {
    const grupo = e.currentTarget.closest("[data-colecao-target='grupo']")
    e.currentTarget.closest(".painel-colecao-linha").remove()
    this.atualizarVazio(grupo)
  }

  atualizarVazio(grupo) {
    const linhas = grupo.querySelector("[data-colecao-target='linhas']")
    const vazio = grupo.querySelector("[data-colecao-target='vazio']")
    if (vazio) vazio.hidden = linhas.children.length > 0
  }
}
