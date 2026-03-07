-- RLS: habilitar em todas as tabelas e políticas

ALTER TABLE polos_regioes ENABLE ROW LEVEL SECURITY;
ALTER TABLE municipios ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessores ENABLE ROW LEVEL SECURITY;
ALTER TABLE apoiadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE votantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE benfeitorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE metas_regionais ENABLE ROW LEVEL SECURITY;
ALTER TABLE meta_estadual ENABLE ROW LEVEL SECURITY;
ALTER TABLE reunioes ENABLE ROW LEVEL SECURITY;
ALTER TABLE concorrentes ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensagens ENABLE ROW LEVEL SECURITY;
ALTER TABLE dados_tse ENABLE ROW LEVEL SECURITY;
ALTER TABLE aniversariantes ENABLE ROW LEVEL SECURITY;

-- Polos e municípios: leitura para todos autenticados
CREATE POLICY "polos_read" ON polos_regioes FOR SELECT TO authenticated USING (true);
CREATE POLICY "municipios_read" ON municipios FOR SELECT TO authenticated USING (true);

-- Profiles: usuário vê o próprio; candidato vê todos; assessor vê árvore
CREATE POLICY "profiles_own" ON profiles FOR ALL TO authenticated
  USING (id = auth.uid());
CREATE POLICY "profiles_candidato_all" ON profiles FOR ALL TO authenticated
  USING (auth.is_candidato());
CREATE POLICY "profiles_assessor_tree" ON profiles FOR SELECT TO authenticated
  USING (invited_by IN (
    SELECT profile_id FROM assessores WHERE id = auth.my_assessor_id()
  ) OR id IN (SELECT * FROM auth.assessor_tree_profile_ids(auth.my_assessor_id())));

-- Assessores: candidato vê todos; assessor vê só a si
CREATE POLICY "assessores_candidato" ON assessores FOR ALL TO authenticated
  USING (auth.is_candidato());
CREATE POLICY "assessores_own" ON assessores FOR ALL TO authenticated
  USING (profile_id = auth.uid());
CREATE POLICY "assessores_read_own" ON assessores FOR SELECT TO authenticated
  USING (auth.can_see_assessor(id));

-- Apoiadores
CREATE POLICY "apoiadores_candidato" ON apoiadores FOR ALL TO authenticated
  USING (auth.is_candidato());
CREATE POLICY "apoiadores_assessor" ON apoiadores FOR ALL TO authenticated
  USING (assessor_id = auth.my_assessor_id());

-- Votantes
CREATE POLICY "votantes_candidato" ON votantes FOR ALL TO authenticated
  USING (auth.is_candidato());
CREATE POLICY "votantes_assessor" ON votantes FOR ALL TO authenticated
  USING (assessor_id = auth.my_assessor_id());

-- Benfeitorias (via apoiador)
CREATE POLICY "benfeitorias_candidato" ON benfeitorias FOR ALL TO authenticated
  USING (auth.is_candidato());
CREATE POLICY "benfeitorias_via_apoiador" ON benfeitorias FOR ALL TO authenticated
  USING (auth.can_see_apoiador(apoiador_id));

-- Metas (candidato e assessores leem; só candidato edita)
CREATE POLICY "metas_regionais_read" ON metas_regionais FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "metas_regionais_candidato" ON metas_regionais FOR ALL TO authenticated
  USING (auth.is_candidato());

-- Meta estadual
CREATE POLICY "meta_estadual_read" ON meta_estadual FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "meta_estadual_candidato" ON meta_estadual FOR ALL TO authenticated
  USING (auth.is_candidato());

-- Reuniões
CREATE POLICY "reunioes_read" ON reunioes FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "reunioes_candidato" ON reunioes FOR ALL TO authenticated
  USING (auth.is_candidato());

-- Concorrentes (leitura todos; escrita candidato)
CREATE POLICY "concorrentes_read" ON concorrentes FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "concorrentes_candidato" ON concorrentes FOR ALL TO authenticated
  USING (auth.is_candidato());

-- Mensagens
CREATE POLICY "mensagens_read" ON mensagens FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "mensagens_candidato" ON mensagens FOR ALL TO authenticated
  USING (auth.is_candidato());

-- Dados TSE (candidato ou assessor leitura)
CREATE POLICY "dados_tse_read" ON dados_tse FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "dados_tse_candidato" ON dados_tse FOR ALL TO authenticated
  USING (auth.is_candidato());

-- Aniversariantes (via árvore)
CREATE POLICY "aniversariantes_candidato" ON aniversariantes FOR ALL TO authenticated
  USING (auth.is_candidato());
CREATE POLICY "aniversariantes_assessor" ON aniversariantes FOR SELECT TO authenticated
  USING (auth.my_assessor_id() IS NOT NULL);
