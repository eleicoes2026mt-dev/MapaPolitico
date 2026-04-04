-- Exclusão de apoiador pelo candidato: oculta da campanha, desativa login, regista em audit como delete (restaurável).

ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS excluido_em TIMESTAMPTZ;

COMMENT ON COLUMN apoiadores.excluido_em IS 'Preenchido quando o candidato exclui o apoiador (soft delete). NULL = ativo na campanha.';

CREATE INDEX IF NOT EXISTS idx_apoiadores_campanha_ativos
  ON apoiadores (assessor_id)
  WHERE excluido_em IS NULL;

-- auth.assessor_ids_do_candidato() pode não existir no projeto (auth não migrável no hosted).
CREATE OR REPLACE FUNCTION public.app_assessor_ids_do_candidato()
RETURNS SETOF UUID AS $$
  SELECT a.id FROM assessores a
  WHERE a.profile_id = auth.uid()
  OR a.profile_id IN (SELECT id FROM profiles WHERE invited_by = auth.uid())
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION public.app_assessor_ids_do_candidato() TO authenticated;

-- Apoiador excluído não entra em can_see_apoiador (benfeitorias / RLS em cadeia).
-- Em Supabase hosted não se pode substituir funções em `auth`; políticas que usavam auth.can_see_apoiador passam a public.can_see_apoiador.
CREATE OR REPLACE FUNCTION public.can_see_apoiador(apoiador_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (SELECT excluido_em FROM apoiadores WHERE id = apoiador_uuid) IS NULL
  AND (
    (public.app_is_candidato() AND (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) IN (SELECT public.app_assessor_ids_do_candidato()))
    OR (SELECT assessor_id FROM apoiadores WHERE id = apoiador_uuid) = public.app_my_assessor_id()
    OR (apoiador_uuid = public.app_my_apoiador_id())
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION public.can_see_apoiador(UUID) TO authenticated;

DROP POLICY IF EXISTS "benfeitorias_via_apoiador" ON benfeitorias;
CREATE POLICY "benfeitorias_via_apoiador" ON benfeitorias FOR ALL TO authenticated
  USING (public.can_see_apoiador(apoiador_id));

-- Policies de apoiador (50322120000) usavam auth.my_apoiador_id; alinhar com ativo em perfil/apoiador.
DROP POLICY IF EXISTS "apoiadores_apoiador_select" ON apoiadores;
CREATE POLICY "apoiadores_apoiador_select" ON apoiadores FOR SELECT TO authenticated
  USING (id = public.app_my_apoiador_id());

DROP POLICY IF EXISTS "apoiadores_apoiador_update" ON apoiadores;
CREATE POLICY "apoiadores_apoiador_update" ON apoiadores FOR UPDATE TO authenticated
  USING (id = public.app_my_apoiador_id())
  WITH CHECK (id = public.app_my_apoiador_id());

DROP POLICY IF EXISTS "votantes_apoiador_all" ON votantes;
CREATE POLICY "votantes_apoiador_all" ON votantes FOR ALL TO authenticated
  USING (apoiador_id IS NOT NULL AND apoiador_id = public.app_my_apoiador_id())
  WITH CHECK (
    apoiador_id = public.app_my_apoiador_id()
    AND assessor_id = (SELECT assessor_id FROM apoiadores WHERE id = public.app_my_apoiador_id())
  );

DROP POLICY IF EXISTS "apoiadores_candidato" ON apoiadores;
CREATE POLICY "apoiadores_candidato" ON apoiadores FOR ALL TO authenticated
  USING (
    public.app_is_candidato()
    AND assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
    AND excluido_em IS NULL
  );

DROP POLICY IF EXISTS "apoiadores_assessor" ON apoiadores;
CREATE POLICY "apoiadores_assessor" ON apoiadores FOR ALL TO authenticated
  USING (assessor_id = public.app_my_assessor_id() AND excluido_em IS NULL);

DROP POLICY IF EXISTS "benfeitorias_candidato" ON benfeitorias;
CREATE POLICY "benfeitorias_candidato" ON benfeitorias FOR ALL TO authenticated
  USING (public.app_is_candidato() AND apoiador_id IN (
    SELECT id FROM apoiadores
    WHERE assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
      AND excluido_em IS NULL
  ));

DROP POLICY IF EXISTS "aniversariantes_candidato" ON aniversariantes;
CREATE POLICY "aniversariantes_candidato" ON aniversariantes FOR ALL TO authenticated
  USING (public.app_is_candidato() AND (
    (tipo_ref = 'assessor' AND ref_id IN (SELECT public.app_assessor_ids_do_candidato()))
    OR (tipo_ref = 'apoiador' AND ref_id IN (
      SELECT id FROM apoiadores
      WHERE assessor_id IN (SELECT public.app_assessor_ids_do_candidato()) AND excluido_em IS NULL
    ))
    OR (tipo_ref = 'votante' AND ref_id IN (SELECT id FROM votantes WHERE assessor_id IN (SELECT public.app_assessor_ids_do_candidato())))
  ));

-- Candidato: exclui apoiador (soft), desativa perfil de login e grava um único evento audit tipo delete (sem duplicar trigger).
CREATE OR REPLACE FUNCTION public.candidato_excluir_apoiador(p_apoiador_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row apoiadores%ROWTYPE;
  v_prof UUID;
  v_candidato UUID;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato pode excluir apoiadores.';
  END IF;

  SELECT * INTO v_row FROM apoiadores WHERE id = p_apoiador_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Apoiador não encontrado.';
  END IF;

  IF NOT (v_row.assessor_id IN (SELECT public.app_assessor_ids_do_candidato())) THEN
    RAISE EXCEPTION 'Apoiador não pertence à sua campanha.';
  END IF;

  IF v_row.excluido_em IS NOT NULL THEN
    RAISE EXCEPTION 'Este apoiador já foi excluído.';
  END IF;

  v_prof := v_row.profile_id;
  v_candidato := auth.uid();

  IF v_prof IS NOT NULL THEN
    UPDATE profiles SET ativo = false WHERE id = v_prof;
  END IF;

  PERFORM set_config('app.audit_restoring', 'true', true);
  UPDATE apoiadores
  SET excluido_em = now(), profile_id = NULL, updated_at = now()
  WHERE id = p_apoiador_id;
  PERFORM set_config('app.audit_restoring', 'false', true);

  PERFORM public.log_campanha_audit_event(
    v_candidato,
    auth.uid(),
    'apoiadores',
    p_apoiador_id,
    'delete',
    to_jsonb(v_row),
    NULL
  );
END;
$$;

COMMENT ON FUNCTION public.candidato_excluir_apoiador IS
  'Candidato: marca apoiador como excluído, remove vínculo de login e desativa o perfil; evento único em campanha_audit_log (restaurável).';

GRANT EXECUTE ON FUNCTION public.candidato_excluir_apoiador(UUID) TO authenticated;

-- Restauração: se a linha ainda existe (soft delete), aplicar snapshot; senão INSERT (exclusões antigas hard delete).
CREATE OR REPLACE FUNCTION public.restaurar_registro_audit(p_log_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r campanha_audit_log%ROWTYPE;
  v_row apoiadores%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role::text = 'candidato'
  ) THEN
    RAISE EXCEPTION 'Apenas o candidato pode restaurar registros';
  END IF;

  SELECT * INTO r FROM campanha_audit_log WHERE id = p_log_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Registro de log não encontrado';
  END IF;
  IF r.candidato_profile_id <> auth.uid() THEN
    RAISE EXCEPTION 'Sem permissão para este log';
  END IF;
  IF r.action <> 'delete' OR r.payload_before IS NULL THEN
    RAISE EXCEPTION 'Só é possível restaurar exclusões com snapshot';
  END IF;

  PERFORM set_config('app.audit_restoring', 'true', true);

  CASE r.table_name
    WHEN 'assessores' THEN
      INSERT INTO assessores SELECT * FROM jsonb_populate_record(NULL::assessores, r.payload_before);
    WHEN 'apoiadores' THEN
      IF EXISTS (SELECT 1 FROM apoiadores WHERE id = r.record_id) THEN
        SELECT * INTO v_row FROM jsonb_populate_record(NULL::apoiadores, r.payload_before);
        UPDATE apoiadores SET
          profile_id = v_row.profile_id,
          assessor_id = v_row.assessor_id,
          nome = v_row.nome,
          tipo = v_row.tipo,
          perfil = v_row.perfil,
          telefone = v_row.telefone,
          email = v_row.email,
          estimativa_votos = v_row.estimativa_votos,
          cidades_atuacao = v_row.cidades_atuacao,
          ativo = v_row.ativo,
          created_at = v_row.created_at,
          updated_at = now(),
          municipio_id = v_row.municipio_id,
          cidade_nome = v_row.cidade_nome,
          data_nascimento = v_row.data_nascimento,
          votos_sozinho = v_row.votos_sozinho,
          qtd_votos_familia = v_row.qtd_votos_familia,
          cnpj = v_row.cnpj,
          razao_social = v_row.razao_social,
          nome_fantasia = v_row.nome_fantasia,
          situacao_cnpj = v_row.situacao_cnpj,
          endereco = v_row.endereco,
          cep = v_row.cep,
          logradouro = v_row.logradouro,
          numero = v_row.numero,
          complemento = v_row.complemento,
          contato_responsavel = v_row.contato_responsavel,
          email_responsavel = v_row.email_responsavel,
          votos_pf = v_row.votos_pf,
          votos_familia = v_row.votos_familia,
          votos_funcionarios = v_row.votos_funcionarios,
          votos_prometidos_ultima_eleicao = v_row.votos_prometidos_ultima_eleicao,
          bandeira_iniciais = v_row.bandeira_iniciais,
          bandeira_cor_primaria = v_row.bandeira_cor_primaria,
          bandeira_cor_secundaria = v_row.bandeira_cor_secundaria,
          bandeira_simbolo = v_row.bandeira_simbolo,
          bandeira_emoji = v_row.bandeira_emoji,
          bandeira_visual = v_row.bandeira_visual,
          excluido_em = v_row.excluido_em
        WHERE id = r.record_id;
        IF v_row.profile_id IS NOT NULL THEN
          UPDATE profiles SET ativo = true WHERE id = v_row.profile_id;
        END IF;
      ELSE
        SELECT * INTO v_row FROM jsonb_populate_record(NULL::apoiadores, r.payload_before);
        INSERT INTO apoiadores SELECT * FROM jsonb_populate_record(NULL::apoiadores, r.payload_before);
        IF v_row.profile_id IS NOT NULL THEN
          UPDATE profiles SET ativo = true WHERE id = v_row.profile_id;
        END IF;
      END IF;
    WHEN 'votantes' THEN
      INSERT INTO votantes SELECT * FROM jsonb_populate_record(NULL::votantes, r.payload_before);
    WHEN 'benfeitorias' THEN
      INSERT INTO benfeitorias SELECT * FROM jsonb_populate_record(NULL::benfeitorias, r.payload_before);
    ELSE
      PERFORM set_config('app.audit_restoring', 'false', true);
      RAISE EXCEPTION 'Tabela não suportada: %', r.table_name;
  END CASE;

  PERFORM set_config('app.audit_restoring', 'false', true);

  INSERT INTO campanha_audit_log (
    candidato_profile_id,
    actor_profile_id,
    table_name,
    record_id,
    action,
    payload_before,
    payload_after
  ) VALUES (
    auth.uid(),
    auth.uid(),
    r.table_name,
    r.record_id,
    'restore',
    NULL,
    r.payload_before
  );
END;
$$;
