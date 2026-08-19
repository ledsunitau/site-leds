# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Editor de texto rico dos posts (Action Text). Os arquivos vêm dos próprios
# gems (action_text-trix e actiontext) pelo asset path do Propshaft — nada
# vendorizado, nada baixado. Carregados só na tela que tem editor
# (yield :head do layout do painel), não no site inteiro.
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
