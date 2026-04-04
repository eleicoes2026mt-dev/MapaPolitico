-- Grava nome, cidade, município e endereço após signup pelo link «Amigos do Gilberto».
-- O UPDATE só pelo cliente pode falhar silenciosamente (RLS WITH CHECK / RETURNING) ou não aplicar cidade_nome.
CREATE OR REPLACE FUNCTION public.finalize_votante_amigos_cadastro(
  p_nome text,
  p_cidade_nome text,
  p_municipio_id uuid,
  p_telefone text,
  p_email text,
  p_abrangencia text,
  p_qtd_votos_familia int,
  p_cep text,
  p_logradouro text,
  p_numero text,
  p_complemento text
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
    complemento = NULLIF(TRIM(p_complemento), '')
  WHERE profile_id = auth.uid();

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'votante não encontrado para este usuário';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.finalize_votante_amigos_cadastro IS
  'Persiste dados do votante após cadastro público pelo link (cidade, município, endereço).';

REVOKE ALL ON FUNCTION public.finalize_votante_amigos_cadastro(
  text, text, uuid, text, text, text, int, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.finalize_votante_amigos_cadastro(
  text, text, uuid, text, text, text, int, text, text, text, text
) TO authenticated;
