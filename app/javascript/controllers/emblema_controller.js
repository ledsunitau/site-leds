import { Controller } from "@hotwired/stimulus"

// Formulário de emblema no painel: prévia de cor/efeito ao vivo e os campos
// que cada tipo realmente usa.
//
// O markup digitado na textarea de SVG NÃO é injetado no DOM de propósito: um
// innerHTML com SVG arbitrário dispararia onload/onerror do que foi colado, e
// um sanitizador em JS só duplicaria (pior) o que o model já faz. O desenho
// aparece depois de salvar; cor e efeito, que é o que se ajusta no tato,
// respondem na hora.
export default class extends Controller {
  static targets = ["cor", "efeito", "previa", "legenda", "criterio", "campoMeta", "nota",
                    "gradiente", "movimento", "velocidade", "amostra", "anel"]

  connect() {
    this.pintar()
    this.pintarCosmetico()
    this.trocarTipo()
  }

  // Prévia do cosmético: o nome e o anel exatamente como vão sair no site.
  // Aqui o valor É seguro para ler — são cores hexadecimais que o próprio
  // gestor digita e que viram valor de CSS, não markup.
  pintarCosmetico() {
    const cores = this.coresValidas
    const grad = cores.length ? `linear-gradient(100deg, ${[...cores, cores[0]].join(", ")})` : "none"
    const dur = `${this.velocidadeTarget.value || 4}s`
    const mov = this.movimentoTarget.value

    for (const alvo of [this.amostraTarget, this.anelTarget]) {
      alvo.style.setProperty("--emblema-grad", grad)
      alvo.style.setProperty("--emblema-vel", dur)
      alvo.classList.remove("cosm-parado", "cosm-varredura", "cosm-fluxo", "cosm-pulso")
      alvo.classList.add(`cosm-${mov}`)
      alvo.classList.toggle("sem-cor", cores.length === 0)
    }
  }

  // Só o que o model aceitaria: 2 ou 3 cores #rrggbb. Enquanto a pessoa digita,
  // a prévia fica na cor neutra em vez de piscar gradiente quebrado.
  get coresValidas() {
    const cores = this.gradienteTarget.value.replace(/\s+/g, "").split(",").filter(Boolean)
    const ok = cores.length >= 2 && cores.length <= 3 && cores.every((c) => /^#[0-9a-f]{6}$/i.test(c))
    return ok ? cores : []
  }

  pintar() {
    this.previaTarget.style.setProperty("--emblema-cor", this.corTarget.value)
    this.previaTarget.className = `emblema-previa emblema-fx-${this.efeitoTarget.value}`
    if (this.hasLegendaTarget) this.legendaTarget.textContent = this.corTarget.value
  }

  // Escalonável não tem meta (o limiar mora em cada rank) e ganha a lista de
  // ranks só depois de salvar. Esconder o campo que não vale evita o gestor
  // preencher um número que o servidor vai descartar.
  trocarTipo() {
    const escalonavel = this.tipo === "escalonavel"
    const temCriterio = this.hasCriterioTarget && this.criterioTarget.value !== ""

    this.element.classList.toggle("e-escalonavel", escalonavel)
    if (this.hasCampoMetaTarget) this.campoMetaTarget.hidden = escalonavel || !temCriterio
    if (this.hasNotaTarget) this.notaTarget.textContent = this.explicacao(escalonavel, temCriterio)
  }

  explicacao(escalonavel, temCriterio) {
    if (!escalonavel) {
      return temCriterio
        ? "Assim que a pessoa bater a meta, o emblema cai sozinho."
        : "Ninguém ganha sozinho: só por concessão da gestão, link exclusivo ou compra."
    }
    return temCriterio
      ? "O rank acompanha a métrica automaticamente. Sem registros itemizados — o hover do perfil não lista eventos."
      : "Cada resgate de link ou concessão vira um REGISTRO com descrição e data, e é isso que faz o rank subir. É o caso da maratona, e é o que aparece no hover do perfil."
  }

  get tipo() {
    const marcado = this.element.querySelector('input[name="emblema[tipo]"]:checked')
    return marcado ? marcado.value : "unico"
  }
}
