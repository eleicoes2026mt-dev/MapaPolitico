-- Cada candidato vê apenas os dados da PRÓPRIA campanha (assessores que ele convidou + ele mesmo).
-- Compartilhado para todos: votacao_secao (eleições passadas) e nomes de regiões (já são leitura geral).

-- IDs dos assessores que pertencem à campanha do candidato atual (ele mesmo + convidados por ele)
CREATE OR REPLACE FUNCTION auth.assessor_ids_do_candidato()
RETURNS SETOF UUID AS $$
  SELECT a.id FROM assessores a
  WHERE a.profile_id = auth.uid()
  OR a.profile_id IN (SELECT id FROM profiles WHERE invited_by = auth.uid())
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Candidato só pode ver assessores da sua campanha; can_see_assessor atualizado
CREATE OR REPLACE FUNCTION auth.can_see_assessor(assessor_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (auth.is_candidato() AND assessor_uuid IN (SELECT auth.assessor_ids_do_candidato()))
  OR (auth.my_assessor_id() = assessor_uuid)
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Candidato só pode ver apoiadores cujo assessor é da sua campanha
CREATE OR REPLACE FUNCTION auth.can_see_apoiador(apoiador_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (auth.is_candidato() AND (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) IN (SELECT auth.assessor_ids_do_candidato()))
  OR (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) = auth.my_assessor_id()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Candidato só pode ver votantes cujo assessor é da sua campanha
CREATE OR REPLACE FUNCTION auth.can_see_votante(votante_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (auth.is_candidato() AND (SELECT assessor_id FROM votantes WHERE id = votante_uuid) IN (SELECT auth.assessor_ids_do_candidato()))
  OR (SELECT assessor_id FROM votantes WHERE id = votante_uuid) = auth.my_assessor_id()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Remover política antiga "candidato vê todos" e criar "candidato vê só da sua campanha"
DROP POLICY IF EXISTS "assessores_candidato" ON assessores;
CREATE POLICY "assessores_candidato" ON assessores FOR ALL TO authenticated
  USING (auth.is_candidato() AND id IN (SELECT auth.assessor_ids_do_candidato()));

DROP POLICY IF EXISTS "apoiadores_candidato" ON apoiadores;
CREATE POLICY "apoiadores_candidato" ON apoiadores FOR ALL TO authenticated
  USING (auth.is_candidato() AND assessor_id IN (SELECT auth.assessor_ids_do_candidato()));

DROP POLICY IF EXISTS "votantes_candidato" ON votantes;
CREATE POLICY "votantes_candidato" ON votantes FOR ALL TO authenticated
  USING (auth.is_candidato() AND assessor_id IN (SELECT auth.assessor_ids_do_candidato()));

DROP POLICY IF EXISTS "benfeitorias_candidato" ON benfeitorias;
CREATE POLICY "benfeitorias_candidato" ON benfeitorias FOR ALL TO authenticated
  USING (auth.is_candidato() AND apoiador_id IN (
    SELECT id FROM apoiadores WHERE assessor_id IN (SELECT auth.assessor_ids_do_candidato())
  ));

-- Aniversariantes: candidato só vê registros da sua campanha (tipo_ref + ref_id)
DROP POLICY IF EXISTS "aniversariantes_candidato" ON aniversariantes;
CREATE POLICY "aniversariantes_candidato" ON aniversariantes FOR ALL TO authenticated
  USING (auth.is_candidato() AND (
    (tipo_ref = 'assessor' AND ref_id IN (SELECT auth.assessor_ids_do_candidato()))
    OR (tipo_ref = 'apoiador' AND ref_id IN (SELECT id FROM apoiadores WHERE assessor_id IN (SELECT auth.assessor_ids_do_candidato())))
    OR (tipo_ref = 'votante' AND ref_id IN (SELECT id FROM votantes WHERE assessor_id IN (SELECT auth.assessor_ids_do_candidato())))
  ));