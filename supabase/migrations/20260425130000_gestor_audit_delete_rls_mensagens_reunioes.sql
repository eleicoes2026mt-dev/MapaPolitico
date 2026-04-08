-- Auditoria visível a candidato e assessor grau 1; exclusões restritas (RLS); logs em mensagens/reuniões/perfil.

-- ── campanha_audit_log: leitura pelo gestor da campanha (raiz = deputado) ──
DROP POLICY IF EXISTS campanha_audit_candidato_select ON public.campanha_audit_log;
DROP POLICY IF EXISTS campanha_audit_gestor_select ON public.campanha_audit_log;
CREATE POLICY campanha_audit_gestor_select ON public.campanha_audit_log
  FOR SELECT TO authenticated
  USING (
    candidato_profile_id = public.app_candidato_raiz_campanha()
    AND public.app_is_candidato()
  );

-- Restaurar exclusão: candidato ou assessor grau 1 (app_is_candidato), mesmo critério do log
CREATE OR REPLACE FUNCTION public.restaurar_registro_audit(p_log_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r campanha_audit_log%ROWTYPE;
  v_raiz uuid;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato ou um assessor de grau 1 pode restaurar registros';
  END IF;

  v_raiz := public.app_candidato_raiz_campanha();
  IF v_raiz IS NULL THEN
    RAISE EXCEPTION 'Não foi possível identificar a campanha';
  END IF;

  SELECT * INTO r FROM campanha_audit_log WHERE id = p_log_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Registro de log não encontrado';
  END IF;
  IF r.candidato_profile_id <> v_raiz THEN
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
      INSERT INTO apoiadores SELECT * FROM jsonb_populate_record(NULL::apoiadores, r.payload_before);
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
    v_raiz,
    auth.uid(),
    r.table_name,
    r.record_id,
    'restore',
    NULL,
    r.payload_before
  );
END;
$$;

COMMENT ON FUNCTION public.restaurar_registro_audit(UUID) IS
  'Restaura registro após delete; candidato ou assessor grau 1 (app_is_candidato).';

-- ── Votantes: assessor grau 2 não pode DELETE (só gestor via política candidato) ──
DROP POLICY IF EXISTS "votantes_assessor" ON public.votantes;
CREATE POLICY "votantes_assessor_select" ON public.votantes
  FOR SELECT TO authenticated
  USING (assessor_id = public.app_my_assessor_id());

CREATE POLICY "votantes_assessor_insert" ON public.votantes
  FOR INSERT TO authenticated
  WITH CHECK (assessor_id = public.app_my_assessor_id());

CREATE POLICY "votantes_assessor_update" ON public.votantes
  FOR UPDATE TO authenticated
  USING (assessor_id = public.app_my_assessor_id())
  WITH CHECK (assessor_id = public.app_my_assessor_id());

-- ── Apoiadores: idem (exclusão via RPC candidato_excluir_apoiador) ──
DROP POLICY IF EXISTS "apoiadores_assessor" ON public.apoiadores;
CREATE POLICY "apoiadores_assessor_select" ON public.apoiadores
  FOR SELECT TO authenticated
  USING (assessor_id = public.app_my_assessor_id() AND excluido_em IS NULL);

CREATE POLICY "apoiadores_assessor_insert" ON public.apoiadores
  FOR INSERT TO authenticated
  WITH CHECK (assessor_id = public.app_my_assessor_id() AND excluido_em IS NULL);

CREATE POLICY "apoiadores_assessor_update" ON public.apoiadores
  FOR UPDATE TO authenticated
  USING (assessor_id = public.app_my_assessor_id() AND excluido_em IS NULL)
  WITH CHECK (assessor_id = public.app_my_assessor_id() AND excluido_em IS NULL);

-- ── Assessores: não permitir DELETE do próprio registro pelo app (só gestor) ──
DROP POLICY IF EXISTS "assessores_own" ON public.assessores;
CREATE POLICY "assessores_own_select" ON public.assessores
  FOR SELECT TO authenticated
  USING (profile_id = auth.uid());

CREATE POLICY "assessores_own_update" ON public.assessores
  FOR UPDATE TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

CREATE POLICY "assessores_own_insert" ON public.assessores
  FOR INSERT TO authenticated
  WITH CHECK (profile_id = auth.uid());

-- ── Triggers: mensagens e reuniões (agenda) ──
CREATE OR REPLACE FUNCTION public.trg_audit_mensagens()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato uuid;
BEGIN
  IF COALESCE(current_setting('app.audit_restoring', true), '') = 'true' THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  v_candidato := public.app_candidato_raiz_campanha();
  IF v_candidato IS NULL THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'mensagens', NEW.id, 'insert', NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'mensagens', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'mensagens', OLD.id, 'delete', to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS mensagens_audit ON public.mensagens;
CREATE TRIGGER mensagens_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.mensagens
  FOR EACH ROW EXECUTE PROCEDURE public.trg_audit_mensagens();

CREATE OR REPLACE FUNCTION public.trg_audit_reunioes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato uuid;
BEGIN
  IF COALESCE(current_setting('app.audit_restoring', true), '') = 'true' THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  v_candidato := public.app_candidato_raiz_campanha();
  IF v_candidato IS NULL THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'reunioes', NEW.id, 'insert', NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'reunioes', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'reunioes', OLD.id, 'delete', to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS reunioes_audit ON public.reunioes;
CREATE TRIGGER reunioes_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.reunioes
  FOR EACH ROW EXECUTE PROCEDURE public.trg_audit_reunioes();

-- Perfil: alteração de papel ou ativação (quem: auth.uid())
CREATE OR REPLACE FUNCTION public.trg_audit_profiles_role_ativo()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato uuid;
BEGIN
  IF COALESCE(current_setting('app.audit_restoring', true), '') = 'true' THEN
    RETURN NEW;
  END IF;
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;
  IF OLD.role IS NOT DISTINCT FROM NEW.role AND OLD.ativo IS NOT DISTINCT FROM NEW.ativo THEN
    RETURN NEW;
  END IF;
  v_candidato := public.app_candidato_raiz_campanha();
  IF v_candidato IS NULL THEN
    RETURN NEW;
  END IF;
  PERFORM public.log_campanha_audit_event(
    v_candidato, auth.uid(), 'profiles', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_audit_role_ativo ON public.profiles;
CREATE TRIGGER profiles_audit_role_ativo
  AFTER UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.trg_audit_profiles_role_ativo();
