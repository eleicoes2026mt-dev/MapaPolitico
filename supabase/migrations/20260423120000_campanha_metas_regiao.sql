-- Metas de votos por região intermediária (cd_rgint) por campanha (perfil do candidato).

CREATE TABLE campanha_metas_regiao (
  candidato_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  cd_rgint TEXT NOT NULL,
  meta_votos BIGINT NOT NULL CHECK (meta_votos > 0),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (candidato_profile_id, cd_rgint)
);

CREATE INDEX idx_campanha_metas_regiao_candidato ON campanha_metas_regiao(candidato_profile_id);

CREATE TRIGGER campanha_metas_regiao_updated_at
  BEFORE UPDATE ON campanha_metas_regiao
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

ALTER TABLE campanha_metas_regiao ENABLE ROW LEVEL SECURITY;

-- Candidato (dono) ou assessor convidado pelo candidato (profiles.invited_by).
CREATE POLICY "campanha_metas_regiao_select" ON campanha_metas_regiao
  FOR SELECT TO authenticated
  USING (
    candidato_profile_id = auth.uid()
    OR candidato_profile_id = (SELECT p.invited_by FROM profiles p WHERE p.id = auth.uid())
  );

CREATE POLICY "campanha_metas_regiao_insert" ON campanha_metas_regiao
  FOR INSERT TO authenticated
  WITH CHECK (
    candidato_profile_id = auth.uid()
    OR candidato_profile_id = (SELECT p.invited_by FROM profiles p WHERE p.id = auth.uid())
  );

CREATE POLICY "campanha_metas_regiao_update" ON campanha_metas_regiao
  FOR UPDATE TO authenticated
  USING (
    candidato_profile_id = auth.uid()
    OR candidato_profile_id = (SELECT p.invited_by FROM profiles p WHERE p.id = auth.uid())
  )
  WITH CHECK (
    candidato_profile_id = auth.uid()
    OR candidato_profile_id = (SELECT p.invited_by FROM profiles p WHERE p.id = auth.uid())
  );

CREATE POLICY "campanha_metas_regiao_delete" ON campanha_metas_regiao
  FOR DELETE TO authenticated
  USING (
    candidato_profile_id = auth.uid()
    OR candidato_profile_id = (SELECT p.invited_by FROM profiles p WHERE p.id = auth.uid())
  );

COMMENT ON TABLE campanha_metas_regiao IS 'Meta de votos por região intermediária (cd_rgint IBGE) por campanha (UUID do candidato em profiles).';
