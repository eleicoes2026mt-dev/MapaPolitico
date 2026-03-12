-- Acelera a consulta de locais de votação por município (evita statement timeout).
-- 1) Índice composto para o filtro usado na busca
CREATE INDEX IF NOT EXISTS idx_votacao_secao_municipio_ano_candidato
  ON votacao_secao (nm_municipio, ano_eleicao, sq_candidato)
  WHERE ano_eleicao = 2022;

-- 2) RPC que agrega no banco (uma varredura indexada + GROUP BY) e devolve só os totais por local
CREATE OR REPLACE FUNCTION get_locais_votacao_por_municipio(
  p_nm_municipio text,
  p_sq_candidato bigint DEFAULT NULL
)
RETURNS TABLE (
  nm_local_votacao text,
  ds_local_votacao_endereco text,
  qt_votos bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    NULLIF(TRIM(v.nm_local_votacao), '') AS nm_local_votacao,
    NULLIF(TRIM(COALESCE(v.ds_local_votacao_endereco, '')), '') AS ds_local_votacao_endereco,
    SUM(v.qt_votos)::bigint AS qt_votos
  FROM votacao_secao v
  WHERE v.ano_eleicao = 2022
    AND TRIM(v.nm_municipio) = TRIM(p_nm_municipio)
    AND (p_sq_candidato IS NULL OR v.sq_candidato = p_sq_candidato)
  GROUP BY NULLIF(TRIM(v.nm_local_votacao), ''), NULLIF(TRIM(COALESCE(v.ds_local_votacao_endereco, '')), '')
  HAVING NULLIF(TRIM(v.nm_local_votacao), '') IS NOT NULL
  ORDER BY qt_votos DESC;
$$;

COMMENT ON FUNCTION get_locais_votacao_por_municipio(text, bigint) IS
  'Retorna locais de votação agregados por município (e opcionalmente por sq_candidato) para evitar timeout no app.';

GRANT EXECUTE ON FUNCTION get_locais_votacao_por_municipio(text, bigint) TO authenticated;
