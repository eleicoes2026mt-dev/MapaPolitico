-- Grau de acesso do assessor: 1 = mesma gestão que o candidato; 2 = padrão (equipe).

ALTER TABLE public.assessores
  ADD COLUMN IF NOT EXISTS grau_acesso SMALLINT NOT NULL DEFAULT 2
    CHECK (grau_acesso IN (1, 2));

COMMENT ON COLUMN public.assessores.grau_acesso IS
  '1 = permissões alinhadas ao candidato; 2 = assessor padrão (convida apoiadores, sem menu completo).';

-- Candidato OU assessor ativo com grau 1: mesmas políticas que usam app_is_candidato().
CREATE OR REPLACE FUNCTION public.app_is_candidato()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'candidato'::public.app_role
      AND COALESCE(ativo, true)
  )
  OR EXISTS (
    SELECT 1
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE a.profile_id = auth.uid()
      AND COALESCE(a.grau_acesso, 2) = 1
      AND COALESCE(a.ativo, true)
      AND COALESCE(p.ativo, true)
  );
$$;

-- Raiz da campanha: perfil do deputado (candidato) a que a equipe está vinculada.
CREATE OR REPLACE FUNCTION public.app_candidato_raiz_campanha()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND role = 'candidato'::public.app_role
        AND COALESCE(ativo, true)
    ) THEN auth.uid()
    ELSE (
      SELECT p.invited_by
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND COALESCE(p.ativo, true)
      LIMIT 1
    )
  END;
$$;

GRANT EXECUTE ON FUNCTION public.app_candidato_raiz_campanha() TO authenticated;

COMMENT ON FUNCTION public.app_candidato_raiz_campanha() IS
  'UUID do perfil candidato da campanha atual (auth.uid() se candidato; senão invited_by).';

-- Lista de assessores.id que o gestor da campanha pode administrar (candidato ou grau 1).
CREATE OR REPLACE FUNCTION public.app_assessor_ids_do_candidato()
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  root uuid;
  gestor boolean;
BEGIN
  gestor := public.app_is_candidato();

  IF gestor THEN
    root := public.app_candidato_raiz_campanha();
    IF root IS NULL THEN
      RETURN;
    END IF;
    RETURN QUERY
    SELECT DISTINCT a.id
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE (
        p.invited_by = root
        OR a.profile_id = uid
      )
      AND COALESCE(a.ativo, true);
    RETURN;
  END IF;

  -- Assessor grau 2 (ou sem gestão): só o próprio registro
  RETURN QUERY
  SELECT a.id
  FROM public.assessores a
  WHERE a.profile_id = uid
    AND COALESCE(a.ativo, true);
END;
$$;

COMMENT ON FUNCTION public.app_assessor_ids_do_candidato() IS
  'IDs em assessores acessíveis ao gestor (candidato ou assessor grau 1) ou ao próprio assessor.';

-- Edge Functions: convidar assessor também para assessor grau 1.
CREATE OR REPLACE FUNCTION public.edge_is_candidato_profile(p_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_id AND role = 'candidato'::public.app_role
  )
  OR EXISTS (
    SELECT 1
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE a.profile_id = p_id
      AND COALESCE(a.grau_acesso, 2) = 1
      AND COALESCE(a.ativo, true)
      AND COALESCE(p.ativo, true)
  );
$$;

-- Alinhar RPC usada por Edge (convites) à mesma árvore de equipe.
CREATE OR REPLACE FUNCTION public.app_assessor_ids_for_candidato_profile(p_candidato uuid)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT a.id
  FROM public.assessores a
  INNER JOIN public.profiles p ON p.id = a.profile_id
  WHERE (
      p.invited_by = p_candidato
      OR a.profile_id = p_candidato
    )
    AND COALESCE(a.ativo, true);
$$;

-- Ativar/desativar assessor: candidato raiz da campanha (inclui assessor grau 1).
CREATE OR REPLACE FUNCTION public.candidato_set_assessor_ativo(p_assessor_id uuid, p_ativo boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile uuid;
  v_me_assessor uuid;
  v_root uuid;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato ou um assessor de grau 1 pode alterar o status do assessor.';
  END IF;

  v_root := public.app_candidato_raiz_campanha();
  IF v_root IS NULL THEN
    RAISE EXCEPTION 'Não foi possível identificar a campanha.';
  END IF;

  SELECT id INTO v_me_assessor FROM public.assessores WHERE profile_id = auth.uid() LIMIT 1;
  IF v_me_assessor IS NOT NULL AND p_assessor_id = v_me_assessor THEN
    RAISE EXCEPTION 'Não é possível desativar o próprio registro de assessor.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE a.id = p_assessor_id
      AND p.invited_by = v_root
  ) THEN
    RAISE EXCEPTION 'Assessor não pertence à sua campanha.';
  END IF;

  SELECT profile_id INTO v_profile FROM public.assessores WHERE id = p_assessor_id;
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'Assessor sem perfil vinculado.';
  END IF;

  UPDATE public.assessores SET ativo = p_ativo WHERE id = p_assessor_id;
  UPDATE public.profiles SET ativo = p_ativo WHERE id = v_profile;
END;
$$;

COMMENT ON FUNCTION public.candidato_set_assessor_ativo(uuid, boolean) IS
  'Candidato ou assessor grau 1: desativa ou reativa assessor convidado.';
