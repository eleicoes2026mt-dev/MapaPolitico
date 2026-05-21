-- Rebaixar papel: antes de remover a linha em assessores, reparentiza apoiadores/votantes
-- que referenciam este assessor — apoiadores.assessor_id tem ON DELETE RESTRICT e fazia o
-- DELETE falhar (transação inteira reverte → pessoa ficava como assessor sem mensagem óbvia no app).

CREATE OR REPLACE FUNCTION public.rebaixar_assessor_para_papel(
  p_assessor_id uuid,
  p_destino text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a_row assessores%ROWTYPE;
  v_dest text;
  v_camp uuid;
  v_raiz uuid;
  v_mun_nome text;
  v_out uuid;
BEGIN
  v_dest := lower(trim(coalesce(p_destino, '')));
  IF v_dest NOT IN ('apoiador', 'votante_amigos') THEN
    RAISE EXCEPTION 'Destino inválido (use ''apoiador'' ou ''votante_amigos'').';
  END IF;

  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o gestor da campanha (candidato ou assessor grau 1) pode rebaixar um assessor.';
  END IF;

  SELECT * INTO a_row FROM public.assessores WHERE id = p_assessor_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assessor não encontrado.';
  END IF;

  IF a_row.profile_id = auth.uid() THEN
    RAISE EXCEPTION 'Não é possível rebaixar a sua própria conta por este fluxo.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.profiles p
    INNER JOIN public.assessores a ON a.profile_id = p.id
    WHERE a.id = p_assessor_id
      AND p.role = 'candidato'::app_role
      AND COALESCE(p.ativo, true)
  ) THEN
    RAISE EXCEPTION 'Não é possível rebaixar o registro de equipa ligado ao candidato.';
  END IF;

  v_camp := public.app_assessor_id_do_candidato();
  IF v_camp IS NULL THEN
    RAISE EXCEPTION 'Campanha sem assessor do candidato; configure antes de continuar.';
  END IF;

  IF p_assessor_id = v_camp THEN
    RAISE EXCEPTION 'Não é possível rebaixar o assessor raiz da campanha.';
  END IF;

  IF a_row.email IS NULL OR btrim(a_row.email::text) = '' THEN
    RAISE EXCEPTION 'E-mail obrigatório no cadastro do assessor para rebaixar.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.apoiadores ap
    WHERE ap.profile_id = a_row.profile_id
      AND ap.excluido_em IS NULL
  ) THEN
    RAISE EXCEPTION 'Já existe um cadastro de apoiador ativo para este utilizador.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.votantes vv
    WHERE vv.profile_id = a_row.profile_id
      AND vv.assessor_id = v_camp
      AND vv.apoiador_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Já existe um cadastro de Amigos «votante» ativo para este utilizador na campanha.';
  END IF;

  SELECT m.nome INTO v_mun_nome FROM public.municipios m WHERE m.id = a_row.municipio_id;

  IF a_row.municipio_id IS NULL OR v_mun_nome IS NULL OR btrim(v_mun_nome) = '' THEN
    RAISE EXCEPTION 'Defina o município completo neste cadastro antes de rebaixar (necessário para apoiador e Amigos Gilberto no mapa).';
  END IF;

  IF v_dest = 'apoiador' THEN
    INSERT INTO public.apoiadores (
      profile_id,
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
      link_instagram,
      cep,
      logradouro,
      numero,
      complemento,
      excluido_em
    ) VALUES (
      a_row.profile_id,
      v_camp,
      a_row.nome,
      'PF'::tipo_pessoa,
      NULLIF(btrim(a_row.telefone), ''),
      lower(NULLIF(btrim(a_row.email::text), '')),
      a_row.municipio_id,
      v_mun_nome,
      1,
      true,
      true,
      0,
      NULLIF(btrim(coalesce(a_row.link_instagram, '')), ''),
      NULLIF(btrim(coalesce(a_row.cep, '')), ''),
      NULLIF(btrim(coalesce(a_row.logradouro, '')), ''),
      NULLIF(btrim(coalesce(a_row.numero, '')), ''),
      NULLIF(btrim(coalesce(a_row.complemento, '')), ''),
      NULL
    )
    RETURNING id INTO v_out;
  ELSE
    INSERT INTO public.votantes (
      profile_id,
      assessor_id,
      nome,
      telefone,
      email,
      municipio_id,
      cidade_nome,
      abrangencia,
      qtd_votos_familia,
      cadastro_via_qr,
      cadastrado_pelo_candidato,
      cep,
      logradouro,
      numero,
      complemento,
      link_instagram,
      convite_por_profile_id,
      convite_por_nome
    ) VALUES (
      a_row.profile_id,
      v_camp,
      a_row.nome,
      NULLIF(btrim(coalesce(a_row.telefone, '')), ''),
      lower(NULLIF(btrim(a_row.email::text), '')),
      a_row.municipio_id,
      v_mun_nome,
      'Individual'::abrangencia_voto,
      1,
      false,
      true,
      NULLIF(btrim(coalesce(a_row.cep, '')), ''),
      NULLIF(btrim(coalesce(a_row.logradouro, '')), ''),
      NULLIF(btrim(coalesce(a_row.numero, '')), ''),
      NULLIF(btrim(coalesce(a_row.complemento, '')), ''),
      NULLIF(btrim(coalesce(a_row.link_instagram, '')), ''),
      NULL,
      NULL
    )
    RETURNING id INTO v_out;
  END IF;

  v_raiz := public.app_candidato_raiz_campanha();
  UPDATE public.profiles SET
    role = CASE WHEN v_dest = 'apoiador' THEN 'apoiador'::app_role ELSE 'votante'::app_role END,
    full_name = COALESCE(NULLIF(btrim(full_name), ''), a_row.nome),
    email = COALESCE(
      NULLIF(btrim(lower(coalesce(email, '')::text)), ''),
      lower(NULLIF(btrim(a_row.email::text), ''))
    ),
    phone = COALESCE(NULLIF(btrim(coalesce(a_row.telefone, '')), ''), phone),
    invited_by = COALESCE(invited_by, v_raiz),
    updated_at = now()
  WHERE id = a_row.profile_id;

  UPDATE public.apoiadores
    SET assessor_id = v_camp, updated_at = now()
  WHERE assessor_id = p_assessor_id;

  UPDATE public.votantes
    SET assessor_id = v_camp, updated_at = now()
  WHERE assessor_id = p_assessor_id;

  DELETE FROM public.assessores WHERE id = p_assessor_id;

  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION public.rebaixar_assessor_para_papel(uuid, text) IS
  'Gestor da campanha: rebaixa assessor para apoiador ou votante «Amigos do Gilberto», preservando profile_id; '
  'reparentiza apoiadores/votantes que apontavam a este assessor (FK RESTRICT) antes do DELETE.';

