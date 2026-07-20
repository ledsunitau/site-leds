# Peso e dimensões da variante — gap conhecido do DDL (documentado no plano):
# a cotação do Melhor Envio (RF-LOJ-11) é impossível sem peso/altura/largura/
# comprimento por item. Nullable: variantes antigas e produtos sob demanda podem
# não ter; a cotação/etiqueta exige presença só quando o produto vai por envio.
class AddDimensoesFreteToVariantes < ActiveRecord::Migration[8.1]
  def change
    change_table :variantes, bulk: true do |t|
      t.decimal :peso, precision: 8, scale: 3        # kg
      t.decimal :altura, precision: 8, scale: 2      # cm
      t.decimal :largura, precision: 8, scale: 2     # cm
      t.decimal :comprimento, precision: 8, scale: 2 # cm
    end

    # positivas quando presentes (o Melhor Envio rejeita zero/negativo)
    add_check_constraint :variantes, "peso IS NULL OR peso > 0", name: "variantes_peso_check"
    add_check_constraint :variantes, "altura IS NULL OR altura > 0", name: "variantes_altura_check"
    add_check_constraint :variantes, "largura IS NULL OR largura > 0", name: "variantes_largura_check"
    add_check_constraint :variantes, "comprimento IS NULL OR comprimento > 0", name: "variantes_comprimento_check"
  end
end
