-- Raiz da campanha (UUID do deputado) e lista de assessores para RLS.
-- Problema: invited_by NULL ou cadeia errada fazia app_candidato_raiz_campanha() = NULL;
-- assessor grau 1 com app_is_candidato() = true ficava só com política «assessor próprio»
-- (apoiadores_assessor_*), sem ver dados da campanha inteira.

-- 1) Sobe invited_by até ao perfil candidato (suporta convite em cadeia).
-- 2) Se ainda NULL e o utilizador é assessor grau 1 ativo: único candidato ativo na base (campanha única).
CREATE OR REPLACE FUNCTION public.app_candidato_raiz_campanha()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  cur uuid;
  v_role public.app_role;
  v_invited uuid;
  v_ativo boolean;
  i int := 0;
BEGIN
  cur := uid;
  WHILE i < 30 LOOP
    SELECT role, invited_by, COALESCE(ativo, true)
    INTO v_role, v_invited, v_ativo
    FROM public.profiles
    WHERE id = cur;
    IF NOT FOUND THEN
      RETURN NULL;
    END IF;
    IF v_role = 'candidato'::public.app_role AND v_ativo THEN
      RETURN cur;
    END IF;
    cur := v_invited;
    IF cur IS NULL THEN
      EXIT;
    END IF;
    i := i + 1;
  END LOOP;

  -- Assessor grau 1 sem cadeia invited_by válida: fallback campanha única
  IF EXISTS (
    SELECT 1
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE a.profile_id = uid
      AND COALESCE(a.grau_acesso, 2) = 1
      AND COALESCE(a.ativo, true)
      AND COALESCE(p.ativo, true)
  ) THEN
    RETURN (
      SELECT c.id
      FROM public.profiles c
      WHERE c.role = 'candidato'::public.app_role
        AND COALESCE(c.ativo, true)
      ORDER BY c.created_at NULLS LAST
      LIMIT 1
    );
  END IF;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.app_candidato_raiz_campanha() IS
  'UUID do perfil candidato da campanha: sobe invited_by até candidato; grau 1 sem árvore usa único candidato na base.';

-- Lista de assessores.id visível ao gestor (candidato ou grau 1).
-- Inclui também assessores com invited_by NULL quando há exatamente um candidato ativo (campanha única).
CREATE OR REPLACE FUNCTION public.app_assessor_ids_do_candidato()
RETURNS SETOF uuid
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  root uuid;
  gestor boolean;
  n_candidatos int;
BEGIN
  gestor := public.app_is_candidato();

  IF gestor THEN
    root := public.app_candidato_raiz_campanha();
    IF root IS NULL THEN
      RETURN;
    END IF;

    SELECT COUNT(*)::int INTO n_candidatos
    FROM public.profiles
    WHERE role = 'candidato'::public.app_role
      AND COALESCE(ativo, true);

    RETURN QUERY
    SELECT DISTINCT a.id
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE COALESCE(a.ativo, true)
      AND (
        p.invited_by = root
        OR a.profile_id = root
        OR (
          n_candidatos = 1
          AND p.invited_by IS NULL
        )
      );
    RETURN;
  END IF;

  RETURN QUERY
  SELECT a.id
  FROM public.assessores a
  WHERE a.profile_id = uid
    AND COALESCE(a.ativo, true);
END;
$$;

COMMENT ON FUNCTION public.app_assessor_ids_do_candidato() IS
  'IDs em assessores acessíveis ao gestor (candidato ou grau 1); campanha única inclui invited_by NULL.';
