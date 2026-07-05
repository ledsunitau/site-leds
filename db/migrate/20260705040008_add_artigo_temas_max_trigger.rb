# RN-18: máximo de 3 temas garantido no BANCO (trigger, como no DDL);
# o mínimo de 1 é validado na aplicação (model Artigo).
class AddArtigoTemasMaxTrigger < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION trg_artigo_temas_max() RETURNS trigger AS $$
      BEGIN
        -- endurecimento documentado sobre o DDL: trava a linha do artigo para
        -- serializar inserts concorrentes; sem isto duas transações passam
        -- do máximo (cada uma vê count=2 e ambas commitam)
        PERFORM 1 FROM artigos WHERE id = NEW.artigo_id FOR UPDATE;
        IF (SELECT count(*) FROM artigo_temas WHERE artigo_id = NEW.artigo_id) >= 3 THEN
          RAISE EXCEPTION 'Um artigo pode ter no máximo 3 temas (artigo_id=%)', NEW.artigo_id;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER artigo_temas_max
        BEFORE INSERT ON artigo_temas
        FOR EACH ROW EXECUTE FUNCTION trg_artigo_temas_max();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER artigo_temas_max ON artigo_temas;
      DROP FUNCTION trg_artigo_temas_max();
    SQL
  end
end
