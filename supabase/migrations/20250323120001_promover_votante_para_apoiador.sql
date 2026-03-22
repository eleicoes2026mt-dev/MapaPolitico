-- Promove votante (PF) a apoiador na mesma campanha (assessor). Apenas candidato ou assessor da linha.

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
    (auth.is_candidato() AND v_row.assessor_id IN (SELECT auth.assessor_ids_do_candidato()))
    OR (auth.my_assessor_id() IS NOT NULL AND auth.my_assessor_id() = v_row.assessor_id)
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
    qtd_votos_familia
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
    0
  )
  RETURNING id INTO v_new_id;

  DELETE FROM votantes WHERE id = p_votante_id;

  RETURN v_new_id;
END;
$$;

COMMENT ON FUNCTION public.promover_votante_para_apoiador(uuid) IS 'Cria apoiador PF a partir do votante e remove o registro de votante (candidato ou assessor da campanha).';

GRANT EXECUTE ON FUNCTION public.promover_votante_para_apoiador(uuid) TO authenticated;
