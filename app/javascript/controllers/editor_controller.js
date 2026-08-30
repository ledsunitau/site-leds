import { Controller } from "@hotwired/stimulus"
import "trix"
import "@rails/actiontext"

// Editor de texto dos posts. O Trix e o Action Text só entram na página que tem
// editor — importar aqui (e não no application.js) mantém o site público sem o
// custo do editor.
//
// Dois modos (RF-NOV-04): "rico" (Trix) e "markdown" (textarea). Os dois campos
// existem no DOM e este controller esconde o que não está em uso — trocar de
// modo não pode perder o que a pessoa já digitou no outro.
// Rótulos da barra em pt-BR (o resto do site é pt-BR — README, "Idioma").
// O Trix monta os títulos a partir do Trix.config.lang, mas sobrescrever aquilo
// é uma corrida: o <trix-editor> pode conectar antes deste controller carregar,
// porque o registro dos controllers é lazy. Traduzir os botões já existentes é
// determinístico e não depende de ordem de carregamento.
const ROTULOS = {
  bold: "Negrito", italic: "Itálico", strike: "Riscado", href: "Link",
  heading1: "Título", quote: "Citação", code: "Código",
  bullet: "Lista", number: "Lista numerada",
  link: "Link", decreaseNestingLevel: "Diminuir recuo", increaseNestingLevel: "Aumentar recuo",
  undo: "Desfazer", redo: "Refazer"
}

// "b" -> "Ctrl+B"; "shift+z" -> "Ctrl+Shift+Z" (o Trix usa a tecla modificadora
// do sistema, mas o rótulo dele é sempre Ctrl — não vale inventar divergência).
function formatarAtalho(chave) {
  const partes = chave.split("+").map((p) => (p.length === 1 ? p.toUpperCase() : p[0].toUpperCase() + p.slice(1)))
  return [ "Ctrl", ...partes ].join("+")
}

export default class extends Controller {
  static targets = ["modo", "campoRico", "campoMarkdown"]

  connect() {
    // Escutado no PRÓPRIO formulário (o evento borbulha), não em window com
    // { once: true }: aquilo pegava só o primeiro editor da vida da página e o
    // listener sobrevivia às navegações do Turbo, acumulando um por visita.
    this.aoInicializar = (e) => this.prepararBarra(e.target)
    this.element.addEventListener("trix-initialize", this.aoInicializar)

    // O Trix pode já ter inicializado antes do Stimulus conectar (a ordem entre
    // o custom element e o controller não é garantida). Sem esta passada, numa
    // volta pelo cache do Turbo a barra ficaria sem limpeza.
    this.element.querySelectorAll("trix-editor").forEach((ed) => this.prepararBarra(ed))

    this.trocarModo()
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.aoInicializar)
  }

  // Idempotente: pode rodar duas vezes no mesmo editor (evento + varredura do
  // connect) sem efeito colateral.
  prepararBarra(editor) {
    const barra = editor?.toolbarElement
    if (!barra) return

    // arquivo/anexo: o upload direto exige Active Storage no formulário e a
    // capa já tem campo próprio — deixar o botão aqui só gera erro mudo.
    barra.querySelector("[data-trix-button-group=file-tools]")?.remove()

    // Título em pt-BR + o atalho de teclado. O Trix só põe o nome, em inglês, e
    // um botão de ícone sem nome ao passar o mouse é adivinhação.
    barra.querySelectorAll(".trix-button").forEach((botao) => {
      const rotulo = ROTULOS[botao.dataset.trixAttribute] || ROTULOS[botao.dataset.trixAction]
      if (!rotulo) return

      const atalho = botao.dataset.trixKey
      botao.setAttribute("title", atalho ? `${rotulo} (${formatarAtalho(atalho)})` : rotulo)
      botao.setAttribute("aria-label", rotulo)
    })
  }

  trocarModo() {
    // Sem os targets (formulário sem os dois modos) não há o que alternar.
    if (!this.hasCampoRicoTarget || !this.hasCampoMarkdownTarget) return

    const markdown = this.modoTargets.find((m) => m.checked)?.value === "markdown"
    this.campoRicoTarget.hidden = markdown
    this.campoMarkdownTarget.hidden = !markdown
  }
}
