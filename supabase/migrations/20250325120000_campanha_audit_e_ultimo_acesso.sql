-- Último acesso aos menus Assessores / Apoiadores (por perfil)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS last_access_assessores_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_access_apoiadores_at TIMESTAMPTZ;

COMMENT ON COLUMN profiles.last_access_assessores_at IS 'Data/hora do último acesso à área Assessores';
COMMENT ON COLUMN profiles.last_access_apoiadores_at IS 'Data/hora do último acesso à área Apoiadores';

-- Log de alterações na campanha (somente leitura/restauração pelo candidato dono)
CREATE TABLE IF NOT EXISTS campanha_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  candidato_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  actor_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('insert', 'update', 'delete', 'restore')),
  payload_before JSONB,
  payload_after JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_campanha_audit_candidato_created
  ON campanha_audit_log (candidato_profile_id, created_at DESC);

COMMENT ON TABLE campanha_audit_log IS 'Histórico insert/update/delete para auditoria e restauração (candidato)';

-- Dono da campanha (deputado) a partir do assessor_id
-- (em public — o SQL Editor do Supabase cloud não permite CREATE no schema auth)
CREATE OR REPLACE FUNCTION public.candidato_profile_id_para_assessor(p_assessor_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT p.invited_by
     FROM profiles p
     INNER JOIN assessores a ON a.profile_id = p.id
     WHERE a.id = p_assessor_id
       AND p.invited_by IS NOT NULL),
    (SELECT p.id
     FROM profiles p
     INNER JOIN assessores a ON a.profile_id = p.id
     WHERE a.id = p_assessor_id
       AND p.role = 'candidato')
  );
$$;

-- Candidato dono a partir de um votante (assessor direto ou via apoiador)
CREATE OR REPLACE FUNCTION public.candidato_profile_id_para_votante(p_votante_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.candidato_profile_id_para_assessor(
    COALESCE(
      (SELECT v.assessor_id FROM votantes v WHERE v.id = p_votante_id),
      (SELECT ap.assessor_id
       FROM votantes v
       INNER JOIN apoiadores ap ON ap.id = v.apoiador_id
       WHERE v.id = p_votante_id)
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.candidato_profile_id_para_benfeitoria(p_benfeitoria_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.candidato_profile_id_para_assessor(
    (SELECT ap.assessor_id
     FROM benfeitorias b
     INNER JOIN apoiadores ap ON ap.id = b.apoiador_id
     WHERE b.id = p_benfeitoria_id)
  );
$$;

-- Insere log (chamado por triggers; SECURITY DEFINER ignora RLS na tabela de audit)
CREATE OR REPLACE FUNCTION public.log_campanha_audit_event(
  p_candidato UUID,
  p_actor UUID,
  p_table TEXT,
  p_record_id UUID,
  p_action TEXT,
  p_before JSONB,
  p_after JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_candidato IS NULL THEN
    RETURN;
  END IF;
  IF COALESCE(current_setting('app.audit_restoring', true), '') = 'true' THEN
    RETURN;
  END IF;
  INSERT INTO campanha_audit_log (
    candidato_profile_id,
    actor_profile_id,
    table_name,
    record_id,
    action,
    payload_before,
    payload_after
  ) VALUES (
    p_candidato,
    p_actor,
    p_table,
    p_record_id,
    p_action,
    p_before,
    p_after
  );
END;
$$;

CREATE OR REPLACE FUNCTION trg_audit_assessores()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato UUID;
BEGIN
  v_candidato := public.candidato_profile_id_para_assessor(COALESCE(NEW.id, OLD.id));
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'assessores', NEW.id, 'insert', NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'assessores', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'assessores', OLD.id, 'delete', to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_audit_apoiadores()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato UUID;
BEGIN
  v_candidato := public.candidato_profile_id_para_assessor(COALESCE(NEW.assessor_id, OLD.assessor_id));
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'apoiadores', NEW.id, 'insert', NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'apoiadores', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'apoiadores', OLD.id, 'delete', to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_audit_votantes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato UUID;
BEGIN
  v_candidato := public.candidato_profile_id_para_votante(COALESCE(NEW.id, OLD.id));
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'votantes', NEW.id, 'insert', NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'votantes', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'votantes', OLD.id, 'delete', to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_audit_benfeitorias()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidato UUID;
BEGIN
  v_candidato := public.candidato_profile_id_para_benfeitoria(COALESCE(NEW.id, OLD.id));
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'benfeitorias', NEW.id, 'insert', NULL, to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'benfeitorias', NEW.id, 'update', to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_campanha_audit_event(
      v_candidato, auth.uid(), 'benfeitorias', OLD.id, 'delete', to_jsonb(OLD), NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS assessores_audit ON assessores;
CREATE TRIGGER assessores_audit
  AFTER INSERT OR UPDATE OR DELETE ON assessores
  FOR EACH ROW EXECUTE PROCEDURE trg_audit_assessores();

DROP TRIGGER IF EXISTS apoiadores_audit ON apoiadores;
CREATE TRIGGER apoiadores_audit
  AFTER INSERT OR UPDATE OR DELETE ON apoiadores
  FOR EACH ROW EXECUTE PROCEDURE trg_audit_apoiadores();

DROP TRIGGER IF EXISTS votantes_audit ON votantes;
CREATE TRIGGER votantes_audit
  AFTER INSERT OR UPDATE OR DELETE ON votantes
  FOR EACH ROW EXECUTE PROCEDURE trg_audit_votantes();

DROP TRIGGER IF EXISTS benfeitorias_audit ON benfeitorias;
CREATE TRIGGER benfeitorias_audit
  AFTER INSERT OR UPDATE OR DELETE ON benfeitorias
  FOR EACH ROW EXECUTE PROCEDURE trg_audit_benfeitorias();

ALTER TABLE campanha_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS campanha_audit_candidato_select ON campanha_audit_log;
CREATE POLICY campanha_audit_candidato_select ON campanha_audit_log
  FOR SELECT TO authenticated
  USING (
    candidato_profile_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role::text = 'candidato'
    )
  );

-- RPC: atualizar último acesso ao menu
CREATE OR REPLACE FUNCTION public.register_menu_access(p_menu TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_menu = 'assessores' THEN
    UPDATE profiles SET last_access_assessores_at = now() WHERE id = auth.uid();
  ELSIF p_menu = 'apoiadores' THEN
    UPDATE profiles SET last_access_apoiadores_at = now() WHERE id = auth.uid();
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_menu_access(TEXT) TO authenticated;

-- RPC: restaurar registro excluído (apenas candidato dono do log)
CREATE OR REPLACE FUNCTION public.restaurar_registro_audit(p_log_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r campanha_audit_log%ROWTYPE;
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

GRANT EXECUTE ON FUNCTION public.restaurar_registro_audit(UUID) TO authenticated;
