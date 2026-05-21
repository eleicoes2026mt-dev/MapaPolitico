-- Promove cadastro «Amigos do Gilberto» (linha em votantes) para assessor da mesma campanha:
-- garante perfil com role assessor + linha em assessores; remove só o registro de votante.
-- Links de rede (convite_por_profile_id, etc.) apontam ao UUID do perfil — mantêm histórico e relatórios.

CREATE OR REPLACE FUNCTION public.promover_votante_para_assessor(
  p_votante_id uuid,
  p_grau_acesso int DEFAULT 2
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- Não usar `public.tabela%ROWTYPE` aqui: o compilador pode interpretar
  -- `public` como nome de relação e falhar com «relation public does not exist».
  v_row votantes%ROWTYPE;
  v_raiz uuid;
  v_grau smallint;
  v_role app_role;
  v_out uuid;
BEGIN
  SELECT * INTO v_row FROM public.votantes WHERE id = p_votante_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Votante não encontrado';
  END IF;

  IF v_row.profile_id IS NULL THEN
    RAISE EXCEPTION 'Só é possível promover quem já tem conta (login) ligada ao cadastro.';
  END IF;

  IF v_row.email IS NULL OR btrim(v_row.email::text) = '' THEN
    RAISE EXCEPTION 'E-mail obrigatório para promover a assessor.';
  END IF;

  IF v_row.apoiador_id IS NOT NULL THEN
    RAISE EXCEPTION 'Votante vinculado a um apoiador. Remova o vínculo ou use outra ação antes.';
  END IF;

  IF v_row.assessor_id IS NULL THEN
    RAISE EXCEPTION 'Votante sem assessor/campanha';
  END IF;

  IF NOT (
    (public.app_is_candidato()
        AND v_row.assessor_id IN (SELECT public.app_assessor_ids_do_candidato()))
    OR (
      public.app_my_assessor_id() IS NOT NULL
      AND public.app_my_assessor_id() = v_row.assessor_id
    )
  ) THEN
    RAISE EXCEPTION 'Sem permissão para promover este votante';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.assessores a WHERE a.profile_id = v_row.profile_id
  ) THEN
    RAISE EXCEPTION 'Este usuário já está cadastrado como assessor';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.apoiadores ap
    WHERE ap.profile_id = v_row.profile_id AND ap.excluido_em IS NULL
  ) THEN
    RAISE EXCEPTION 'Este utilizador já está vinculado a um cadastro de apoiador ativo.';
  END IF;

  SELECT p.role INTO v_role FROM public.profiles p WHERE p.id = v_row.profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil de utilizador não encontrado.';
  END IF;
  IF v_role = 'candidato'::app_role THEN
    RAISE EXCEPTION 'Não é possível usar este fluxo sobre o cadastro do candidato.';
  END IF;

  v_raiz := public.app_candidato_raiz_campanha();
  IF v_raiz IS NULL THEN
    RAISE EXCEPTION 'Não foi possível identificar o candidato da campanha.';
  END IF;

  IF v_raiz = v_row.profile_id THEN
    RAISE EXCEPTION 'Este utilizador já é raiz da campanha.';
  END IF;

  v_grau := 2::smallint;
  IF p_grau_acesso = 1 THEN
    IF public.app_is_candidato()
       OR EXISTS (
         SELECT 1 FROM public.assessores ax
         WHERE ax.profile_id = auth.uid()
           AND COALESCE(ax.ativo, true)
           AND ax.grau_acesso = 1
       )
    THEN
      v_grau := 1::smallint;
    END IF;
  END IF;

  INSERT INTO public.assessores (
    profile_id,
    nome,
    telefone,
    email,
    municipio_id,
    ativo,
    grau_acesso,
    link_instagram,
    cep,
    logradouro,
    numero,
    complemento
  )
  VALUES (
    v_row.profile_id,
    v_row.nome,
    NULLIF(btrim(v_row.telefone), ''),
    lower(NULLIF(btrim(v_row.email::text), '')),
    v_row.municipio_id,
    true,
    v_grau,
    NULLIF(btrim(v_row.link_instagram), ''),
    NULLIF(btrim(v_row.cep), ''),
    NULLIF(btrim(v_row.logradouro), ''),
    NULLIF(btrim(v_row.numero), ''),
    NULLIF(btrim(v_row.complemento), '')
  )
  ON CONFLICT (profile_id) DO UPDATE SET
    nome = excluded.nome,
    telefone = excluded.telefone,
    email = COALESCE(excluded.email, assessores.email),
    municipio_id = COALESCE(excluded.municipio_id, assessores.municipio_id),
    ativo = true,
    grau_acesso = excluded.grau_acesso,
    link_instagram = COALESCE(excluded.link_instagram, assessores.link_instagram),
    cep = COALESCE(excluded.cep, assessores.cep),
    logradouro = COALESCE(excluded.logradouro, assessores.logradouro),
    numero = COALESCE(excluded.numero, assessores.numero),
    complemento = COALESCE(excluded.complemento, assessores.complemento),
    updated_at = now()
  RETURNING id INTO v_out;

  UPDATE public.profiles p SET
    role = 'assessor'::app_role,
    invited_by = v_raiz,
    full_name = COALESCE(NULLIF(btrim(p.full_name), ''), v_row.nome),
    email = COALESCE(
      NULLIF(btrim(lower(COALESCE(p.email, '')::text)), ''),
      lower(NULLIF(btrim(v_row.email::text), ''))
    ),
    phone = COALESCE(NULLIF(btrim(v_row.telefone), ''), p.phone),
    updated_at = now()
  WHERE p.id = v_row.profile_id;

  DELETE FROM public.votantes WHERE id = p_votante_id;

  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION public.promover_votante_para_assessor(uuid, int) IS
  'Gestor da campanha: promove votante com conta (profile_id + e-mail) a assessor, preservando rede por UUID do perfil; remove apenas a linha em votantes.';

GRANT EXECUTE ON FUNCTION public.promover_votante_para_assessor(uuid, int) TO authenticated;
