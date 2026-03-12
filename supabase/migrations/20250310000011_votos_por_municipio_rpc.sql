-- Soma qt_votos por nm_municipio para um candidato (evita limite de 1000 linhas do Supabase no select).
-- Assim o mapa mostra o total correto (ex.: 28.248 votos) e todas as cidades.

CREATE INDEX IF NOT EXISTS idx_votacao_secao_ano_candidato
  ON votacao_secao (ano_eleicao, sq_candidato)
  WHERE ano_eleicao = 2022;

CREATE OR REPLACE FUNCTION get_votos_por_municipio(p_sq_candidato bigint)
RETURNS TABLE (nm_municipio text, qt_votos bigint)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    NULLIF(TRIM(v.nm_municipio), '') AS nm_municipio,
    SUM(v.qt_votos)::bigint AS qt_votos
  FROM votacao_secao v
  WHERE v.ano_eleicao = 2022
    AND v.sq_candidato = p_sq_candidato
    AND TRIM(v.nm_municipio) <> ''
  GROUP BY NULLIF(TRIM(v.nm_municipio), '')
  ORDER BY qt_votos DESC;
$$;

COMMENT ON FUNCTION get_votos_por_municipio(bigint) IS
  'Retorna totais de votos por município para um candidato (2022). Usado no mapa para exibir todas as cidades e soma correta.';

GRANT EXECUTE ON FUNCTION get_votos_por_municipio(bigint) TO authenticated;
