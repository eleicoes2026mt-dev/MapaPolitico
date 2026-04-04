-- Se existir assinatura antiga (boolean), substitui.
DROP FUNCTION IF EXISTS public.edge_can_manage_apoiador_invite(uuid, uuid);

-- Gate do convite/reconvite de apoiador nas Edge Functions: uma única função SECURITY DEFINER
-- que não depende de auth.uid() nem de leituras PostgREST sujeitas a RLS com o JWT do serviço.
-- Replica a lógica de assertCanManageApoiador (apoiador-gate.ts) + app_assessor_ids_for_candidato_profile.
-- Retorno jsonb: { "ok": true } ou { "ok": false, "code": "..." } para mensagens no Deno.

CREATE OR REPLACE FUNCTION public.edge_can_manage_apoiador_invite(p_caller uuid, p_apoiador uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_role app_role;
  v_assessor_apoiador uuid;
  v_candidato uuid;
  v_cur uuid;
  v_invited_by uuid;
  v_profile_role app_role;
  v_my_assessor_id uuid;
  depth int := 0;
  v_in_campaign boolean;
BEGIN
  SELECT role INTO v_role FROM profiles WHERE id = p_caller;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'no_profile');
  END IF;

  SELECT assessor_id INTO v_assessor_apoiador
  FROM apoiadores
  WHERE id = p_apoiador AND excluido_em IS NULL;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'no_apoiador');
  END IF;

  IF v_role = 'candidato' THEN
    v_in_campaign := EXISTS (
      SELECT 1
      FROM assessores a
      WHERE a.id = v_assessor_apoiador
        AND (
          a.profile_id = p_caller
          OR a.profile_id IN (SELECT id FROM profiles WHERE invited_by = p_caller)
        )
    );
    IF v_in_campaign THEN
      RETURN jsonb_build_object('ok', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'not_campaign');
  END IF;

  IF v_role = 'assessor' THEN
    v_candidato := NULL;
    v_cur := p_caller;
    WHILE depth < 40 LOOP
      SELECT invited_by, role INTO v_invited_by, v_profile_role FROM profiles WHERE id = v_cur;
      IF NOT FOUND THEN
        EXIT;
      END IF;
      IF v_profile_role = 'candidato' THEN
        v_candidato := v_cur;
        EXIT;
      END IF;
      IF v_invited_by IS NULL THEN
        EXIT;
      END IF;
      v_cur := v_invited_by;
      depth := depth + 1;
    END LOOP;

    IF v_candidato IS NOT NULL THEN
      v_in_campaign := EXISTS (
        SELECT 1
        FROM assessores a
        WHERE a.id = v_assessor_apoiador
          AND (
            a.profile_id = v_candidato
            OR a.profile_id IN (SELECT id FROM profiles WHERE invited_by = v_candidato)
          )
      );
      IF v_in_campaign THEN
        RETURN jsonb_build_object('ok', true);
      END IF;
      RETURN jsonb_build_object('ok', false, 'code', 'not_campaign');
    END IF;

    SELECT id INTO v_my_assessor_id FROM assessores WHERE profile_id = p_caller LIMIT 1;
    IF v_my_assessor_id IS NOT NULL AND v_my_assessor_id = v_assessor_apoiador THEN
      RETURN jsonb_build_object('ok', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'strict_assessor');
  END IF;

  RETURN jsonb_build_object('ok', false, 'code', 'forbidden_role');
END;
$$;

COMMENT ON FUNCTION public.edge_can_manage_apoiador_invite(uuid, uuid) IS
  'Usado pelas Edge Functions (service role): quem pode convidar/reconvidar este apoiador.';

GRANT EXECUTE ON FUNCTION public.edge_can_manage_apoiador_invite(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.edge_can_manage_apoiador_invite(uuid, uuid) TO authenticated;

-- convidar-assessor / reenviar-convite-assessor: evita depender só de .from('profiles') via PostgREST
CREATE OR REPLACE FUNCTION public.edge_is_candidato_profile(p_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = p_id AND role = 'candidato'::app_role
  );
$$;

COMMENT ON FUNCTION public.edge_is_candidato_profile(uuid) IS
  'Edge Functions: o utilizador é candidato? (RLS-agnostic).';

GRANT EXECUTE ON FUNCTION public.edge_is_candidato_profile(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.edge_is_candidato_profile(uuid) TO authenticated;
