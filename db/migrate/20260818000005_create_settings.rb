# Configurações da loja controladas pela gestão (RF-LOJ / painel admin futuro):
# key/value simples. Hoje guarda `loja_ativa` (liga/desliga a loja) e
# `modo_pagamento` (direto = intenção de compra ↔ mercado_pago quando houver
# conta). Auditado como o resto (PaperTrail no model).
class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :chave, null: false
      t.string :valor
      t.timestamps
    end

    add_index :settings, :chave, unique: true
  end
end
