# Funções (papéis) deixam de ser lista fechada no código e viram cadastro.
#
# Antes o mesmo conjunto vivia em TRÊS lugares — constante Ruby, enum do Rails e
# CHECK do Postgres — e adicionar um papel exigia deploy. A tabela passa a ser a
# fonte única, então os dois CHECKs saem junto (senão o cadastro criaria funções
# que o banco recusa na hora de gravar a contribuição).
#
# `papel` continua varchar nas junções, sem FK: o índice único
# (projeto, membro, papel) e o JSON da API seguem valendo sem migrar linha
# nenhuma. O preço é renomear função em uso não ser automático — o painel recusa.
class FuncoesCadastraveis < ActiveRecord::Migration[8.1]
  def up
    create_table :funcoes do |t|
      t.string  :modalidade, null: false
      t.string  :nome, null: false
      t.boolean :protegida, null: false, default: false

      t.timestamps
    end

    add_index :funcoes, [ :modalidade, :nome ], unique: true
    add_check_constraint :funcoes, "modalidade IN ('projeto','evento')",
                         name: "funcoes_modalidade_check"

    # Semeado aqui e não em seeds.rb: produção já tem dados, e seeds.rb só roda
    # em setup — sem estas linhas a validação recusaria TODO papel já gravado.
    # organizador/participante nascem protegidos: a API pública separa
    # `organizadores` e `participantes` por esses nomes (AcoesController#detalhe_json).
    execute <<~SQL
      INSERT INTO funcoes (modalidade, nome, protegida, created_at, updated_at) VALUES
        ('projeto', 'backend',      false, NOW(), NOW()),
        ('projeto', 'frontend',     false, NOW(), NOW()),
        ('projeto', 'ui_ux',        false, NOW(), NOW()),
        ('projeto', 'design',       false, NOW(), NOW()),
        ('projeto', 'infra',        false, NOW(), NOW()),
        ('projeto', 'outro',        false, NOW(), NOW()),
        ('evento',  'organizador',  true,  NOW(), NOW()),
        ('evento',  'participante', true,  NOW(), NOW());
    SQL

    remove_check_constraint :contribuicoes, name: "contribuicoes_papel_check"
    remove_check_constraint :evento_membros, name: "evento_membros_papel_check"
  end

  def down
    # Restaura os CHECKs com a lista original; papéis criados depois viram
    # violação — de propósito, é o que "voltar para lista fechada" significa.
    add_check_constraint :contribuicoes,
                         "papel IN ('backend','frontend','ui_ux','design','infra','outro')",
                         name: "contribuicoes_papel_check"
    add_check_constraint :evento_membros, "papel IN ('organizador','participante')",
                         name: "evento_membros_papel_check"
    drop_table :funcoes
  end
end
