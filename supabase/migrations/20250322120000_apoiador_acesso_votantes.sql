-- Apoiador com login: vê só o próprio cadastro, gere seus votantes (mapa / estimativa).

CREATE OR REPLACE FUNCTION auth.my_apoiador_id()
RETURNS UUID AS $$
  SELECT id FROM apoiadores WHERE profile_id = auth.uid() LIMIT 1
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION auth.is_apoiador()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'apoiador')
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Apoiador enxerga o próprio registro em apoiadores
CREATE OR REPLACE FUNCTION auth.can_see_apoiador(apoiador_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (auth.is_candidato() AND (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) IN (SELECT auth.assessor_ids_do_candidato()))
  OR (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) = auth.my_assessor_id()
  OR (apoiador_uuid = auth.my_apoiador_id())
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION auth.can_see_votante(votante_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (auth.is_candidato() AND (SELECT assessor_id FROM votantes WHERE id = votante_uuid) IN (SELECT auth.assessor_ids_do_candidato()))
  OR (SELECT assessor_id FROM votantes WHERE id = votante_uuid) = auth.my_assessor_id()
  OR ((SELECT apoiador_id FROM votantes WHERE id = votante_uuid) IS NOT NULL
      AND (SELECT apoiador_id FROM votantes WHERE id = votante_uuid) = auth.my_apoiador_id())
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Leitura do próprio apoiador (além das políticas de candidato/assessor)
CREATE POLICY "apoiadores_apoiador_select" ON apoiadores FOR SELECT TO authenticated
  USING (id = auth.my_apoiador_id());

CREATE POLICY "apoiadores_apoiador_update" ON apoiadores FOR UPDATE TO authenticated
  USING (id = auth.my_apoiador_id())
  WITH CHECK (id = auth.my_apoiador_id());

-- Votantes do apoiador logado
CREATE POLICY "votantes_apoiador_all" ON votantes FOR ALL TO authenticated
  USING (apoiador_id IS NOT NULL AND apoiador_id = auth.my_apoiador_id())
  WITH CHECK (
    apoiador_id = auth.my_apoiador_id()
    AND assessor_id = (SELECT assessor_id FROM apoiadores WHERE id = auth.my_apoiador_id())
  );

COMMENT ON FUNCTION auth.my_apoiador_id() IS 'UUID da linha apoiadores ligada ao usuário logado (convite por e-mail)';
