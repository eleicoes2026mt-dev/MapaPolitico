-- Funções auxiliares para RLS (árvore do usuário)

-- Retorna o role do usuário atual
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS app_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Retorna o assessor_id do perfil atual (se for assessor)
CREATE OR REPLACE FUNCTION auth.my_assessor_id()
RETURNS UUID AS $$
  SELECT a.id FROM assessores a WHERE a.profile_id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verifica se o usuário é candidato (admin master)
CREATE OR REPLACE FUNCTION auth.is_candidato()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'candidato')
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- IDs de perfis na árvore do assessor (assessor + apoiadores + votantes vinculados)
CREATE OR REPLACE FUNCTION auth.assessor_tree_profile_ids(assessor_uuid UUID)
RETURNS SETOF UUID AS $$
  SELECT p.id FROM profiles p
  WHERE p.invited_by = (SELECT profile_id FROM assessores WHERE id = assessor_uuid)
  UNION
  SELECT p.id FROM apoiadores ap
  JOIN profiles p ON p.id = ap.profile_id
  WHERE ap.assessor_id = assessor_uuid
  UNION
  SELECT p.id FROM votantes v
  JOIN profiles p ON p.id = v.profile_id
  WHERE v.assessor_id = assessor_uuid
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Perfil atual pode ver este assessor? (candidato ou é o próprio assessor)
CREATE OR REPLACE FUNCTION auth.can_see_assessor(assessor_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT auth.is_candidato() OR auth.my_assessor_id() = assessor_uuid
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Perfil atual pode ver este apoiador? (candidato ou apoiador pertence ao assessor)
CREATE OR REPLACE FUNCTION auth.can_see_apoiador(apoiador_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT auth.is_candidato()
  OR (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) = auth.my_assessor_id()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Perfil atual pode ver este votante?
CREATE OR REPLACE FUNCTION auth.can_see_votante(votante_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT auth.is_candidato()
  OR (SELECT assessor_id FROM votantes WHERE id = votante_uuid) = auth.my_assessor_id()
$$ LANGUAGE sql SECURITY DEFINER STABLE;
