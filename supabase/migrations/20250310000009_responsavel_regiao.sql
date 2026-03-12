-- Responsável por região (Estratégia > Responsáveis). Uma região pode ter um assessor atribuído.
CREATE TABLE IF NOT EXISTS responsavel_regiao (
  regiao_id TEXT PRIMARY KEY,
  assessor_id UUID NOT NULL REFERENCES assessores(id) ON DELETE CASCADE
);

COMMENT ON TABLE responsavel_regiao IS 'Assessor responsável por cada região (id = RegiaoEfetiva.id da tela Estratégia)';

ALTER TABLE responsavel_regiao ENABLE ROW LEVEL SECURITY;

CREATE POLICY "responsavel_regiao_select_authenticated"
  ON responsavel_regiao FOR SELECT TO authenticated USING (true);

CREATE POLICY "responsavel_regiao_insert_candidato"
  ON responsavel_regiao FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'candidato')
  );

CREATE POLICY "responsavel_regiao_update_candidato"
  ON responsavel_regiao FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'candidato'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'candidato'));

CREATE POLICY "responsavel_regiao_delete_candidato"
  ON responsavel_regiao FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'candidato'));

GRANT SELECT, INSERT, UPDATE, DELETE ON responsavel_regiao TO authenticated;
