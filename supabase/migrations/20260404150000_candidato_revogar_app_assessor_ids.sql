-- Corrige RPC já implantada quando auth.assessor_ids_do_candidato() não existe no projeto (Supabase hosted).
-- Depende de public.app_assessor_ids_do_candidato() (20260404140000 ou 20250403140000).

CREATE OR REPLACE FUNCTION public.candidato_revogar_acesso_apoiador(p_apoiador_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof UUID;
  v_assessor UUID;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato pode revogar o acesso do apoiador.';
  END IF;

  SELECT assessor_id, profile_id INTO v_assessor, v_prof
  FROM apoiadores WHERE id = p_apoiador_id;

  IF v_assessor IS NULL THEN
    RAISE EXCEPTION 'Apoiador não encontrado.';
  END IF;

  IF NOT (v_assessor IN (SELECT public.app_assessor_ids_do_candidato())) THEN
    RAISE EXCEPTION 'Apoiador não pertence à sua campanha.';
  END IF;

  UPDATE apoiadores SET profile_id = NULL WHERE id = p_apoiador_id;

  IF v_prof IS NOT NULL THEN
    UPDATE profiles SET ativo = false WHERE id = v_prof;
  END IF;
END;
$$;
