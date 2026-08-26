// Registra os controllers do importmap SOB DEMANDA: o lazy loader observa o DOM
// e importa cada controller quando o data-controller dele aparece. Antes era
// eager — 24 fetches de módulo + 24 hints de modulepreload em toda carga
// completa, para uma página que usa 2 ou 3. O par obrigatório disto é o
// `preload: false` no pin_all_from do config/importmap.rb: sem ele o browser
// continuaria pré-carregando os 24 que o lazy loader não vai pedir.
//
// Funciona dentro de Turbo Frame: o observador é do documento, então controller
// que chega num frame trocado é registrado igual.
import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
lazyLoadControllersFrom("controllers", application)
