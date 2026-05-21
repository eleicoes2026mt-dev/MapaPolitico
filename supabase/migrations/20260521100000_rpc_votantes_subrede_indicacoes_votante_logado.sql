-- Rede «Minhas indicações» (role=votante): o SELECT pela RLS só permitia linhas profile_id = auth.uid().
-- Devolve própria linha + convidados + níveis seguintes (convite_por_profile_id) na mesma campanha.

CREATE OR REPLACE FUNCTION public.app_norm_text_indicacao(t text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT upper(trim(regexp_replace(coalesce(trim(t), ''), E'\\s+', ' ', 'g')));
$$;

COMMENT ON FUNCTION public.app_norm_text_indicacao(text) IS
  'Normalização simples para comparar texto de indicação (maiúsculas + espaços).';

CREATE OR REPLACE FUNCTION public.app_votantes_subrede_indicacoes_votante_logado()
RETURNS SETOF public.votantes
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH RECURSIVE camp_ass AS (
    SELECT public.app_assessor_id_do_candidato() AS aid
  ),
  inv_norm AS (
    SELECT public.app_norm_text_indicacao(
      COALESCE(
        (SELECT v.nome FROM public.votantes v CROSS JOIN camp_ass c
         WHERE v.profile_id = auth.uid() AND v.assessor_id = c.aid
         ORDER BY v.id ASC LIMIT 1),
        (SELECT p.full_name FROM public.profiles p WHERE p.id = auth.uid()),
        ''
      )) AS nk
  ),
  sub AS (
    SELECT v.*
    FROM public.votantes v
    CROSS JOIN camp_ass c
    CROSS JOIN inv_norm inm
    WHERE public.app_is_profile_votante_qr()
      AND v.assessor_id = c.aid
      AND (
        v.profile_id = auth.uid()
        OR v.convite_por_profile_id = auth.uid()
        OR (
          v.convite_por_nome IS NOT NULL AND trim(v.convite_por_nome) <> ''
          AND inm.nk <> ''
          AND public.app_norm_text_indicacao(v.convite_por_nome) = inm.nk
        )
      )

    UNION

    SELECT w.*
    FROM public.votantes w
    INNER JOIN camp_ass c ON w.assessor_id = c.aid
    INNER JOIN sub s ON (
      w.convite_por_profile_id = s.profile_id
      OR (
        w.convite_por_profile_id IS NULL
        AND COALESCE(trim(w.convite_por_nome), '') <> ''
        AND COALESCE(trim(s.nome), '') <> ''
        AND public.app_norm_text_indicacao(w.convite_por_nome)
          = public.app_norm_text_indicacao(s.nome)
      )
    )
    WHERE public.app_is_profile_votante_qr()
      AND s.profile_id IS NOT NULL
  )
  SELECT DISTINCT ON (s.id) s.*
  FROM sub s
  ORDER BY s.id;
$$;

COMMENT ON FUNCTION public.app_votantes_subrede_indicacoes_votante_logado() IS
  'Lista votantes do assessor da campanha ligados ao votante logado para a rede de indicações: própria linha, '
  'convidados pelo perfil (convite_por_profile_id ou convite_por_nome = nome normalizado), '
  'e níveis seguintes onde convite_por_profile_id aponta para alguém da sublista ou (sem UUID) pelo nome igual ao da linha pai.';

GRANT EXECUTE ON FUNCTION public.app_norm_text_indicacao(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_votantes_subrede_indicacoes_votante_logado() TO authenticated;
