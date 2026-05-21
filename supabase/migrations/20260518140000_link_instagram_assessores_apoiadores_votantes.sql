-- Link público do Instagram (URL ou @usuario) para assessores, apoiadores e votantes.

ALTER TABLE public.assessores ADD COLUMN IF NOT EXISTS link_instagram text;
COMMENT ON COLUMN public.assessores.link_instagram IS 'Perfil Instagram: URL ou @usuario (opcional).';

ALTER TABLE public.apoiadores ADD COLUMN IF NOT EXISTS link_instagram text;
COMMENT ON COLUMN public.apoiadores.link_instagram IS 'Perfil Instagram: URL ou @usuario (opcional).';

ALTER TABLE public.votantes ADD COLUMN IF NOT EXISTS link_instagram text;
COMMENT ON COLUMN public.votantes.link_instagram IS 'Perfil Instagram: URL ou @usuario (opcional).';

-- Cadastro público Amigos: parâmetro extra (NULL = não alterar coluna existente).
DROP FUNCTION IF EXISTS public.finalize_votante_amigos_cadastro(
  text, text, uuid, text, text, text, int, text, text, text, text
);

CREATE OR REPLACE FUNCTION public.finalize_votante_amigos_cadastro(
  p_nome text DEFAULT NULL,
  p_cidade_nome text DEFAULT NULL,
  p_municipio_id uuid DEFAULT NULL,
  p_telefone text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_abrangencia text DEFAULT NULL,
  p_qtd_votos_familia int DEFAULT NULL,
  p_cep text DEFAULT NULL,
  p_logradouro text DEFAULT NULL,
  p_numero text DEFAULT NULL,
  p_complemento text DEFAULT NULL,
  p_link_instagram text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated int;
  v_abr public.abrangencia_voto;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  PERFORM public.ensure_votante_amigos_cadastro();

  IF NULLIF(TRIM(p_cidade_nome), '') IS NULL THEN
    RAISE EXCEPTION 'cidade_nome obrigatório';
  END IF;

  IF p_abrangencia IN ('Individual', 'Familiar') THEN
    v_abr := p_abrangencia::public.abrangencia_voto;
  ELSE
    v_abr := 'Individual'::public.abrangencia_voto;
  END IF;

  UPDATE public.votantes
  SET
    nome = COALESCE(NULLIF(TRIM(p_nome), ''), nome),
    cidade_nome = NULLIF(TRIM(p_cidade_nome), ''),
    municipio_id = p_municipio_id,
    telefone = NULLIF(TRIM(p_telefone), ''),
    email = NULLIF(LOWER(TRIM(p_email)), ''),
    abrangencia = v_abr,
    qtd_votos_familia = GREATEST(1, COALESCE(p_qtd_votos_familia, 1)),
    cep = NULLIF(TRIM(p_cep), ''),
    logradouro = NULLIF(TRIM(p_logradouro), ''),
    numero = NULLIF(TRIM(p_numero), ''),
    complemento = NULLIF(TRIM(p_complemento), ''),
    link_instagram = CASE
      WHEN p_link_instagram IS NULL THEN link_instagram
      ELSE NULLIF(TRIM(p_link_instagram), '')
    END
  WHERE profile_id = auth.uid();

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'votante não encontrado para este usuário após ensure_votante_amigos_cadastro';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.finalize_votante_amigos_cadastro IS
  'Após signup: persiste cidade/município/endereço e opcionalmente Instagram (p_link_instagram NULL = manter valor).';

REVOKE ALL ON FUNCTION public.finalize_votante_amigos_cadastro(
  text, text, uuid, text, text, text, int, text, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.finalize_votante_amigos_cadastro(
  text, text, uuid, text, text, text, int, text, text, text, text, text
) TO authenticated;

-- Promover votante → apoiador: copiar Instagram quando existir.
CREATE OR REPLACE FUNCTION public.promover_votante_para_apoiador(p_votante_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row votantes%ROWTYPE;
  v_nome_municipio text;
  v_new_id uuid;
BEGIN
  SELECT * INTO v_row FROM votantes WHERE id = p_votante_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Votante não encontrado';
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

  IF v_row.apoiador_id IS NOT NULL THEN
    RAISE EXCEPTION 'Votante já vinculado a um apoiador. Remova o vínculo antes de promover.';
  END IF;

  IF v_row.municipio_id IS NULL THEN
    RAISE EXCEPTION 'Defina o município do votante antes de promover.';
  END IF;

  SELECT m.nome INTO v_nome_municipio FROM municipios m WHERE m.id = v_row.municipio_id;
  IF v_nome_municipio IS NULL OR btrim(v_nome_municipio) = '' THEN
    RAISE EXCEPTION 'Município inválido';
  END IF;

  INSERT INTO apoiadores (
    assessor_id,
    nome,
    tipo,
    telefone,
    email,
    municipio_id,
    cidade_nome,
    estimativa_votos,
    ativo,
    votos_sozinho,
    qtd_votos_familia,
    link_instagram
  ) VALUES (
    v_row.assessor_id,
    v_row.nome,
    'PF'::tipo_pessoa,
    v_row.telefone,
    v_row.email,
    v_row.municipio_id,
    v_nome_municipio,
    GREATEST(1, COALESCE(v_row.qtd_votos_familia, 1)),
    true,
    true,
    0,
    NULLIF(TRIM(v_row.link_instagram), '')
  )
  RETURNING id INTO v_new_id;

  DELETE FROM votantes WHERE id = p_votante_id;

  RETURN v_new_id;
END;
$$;
