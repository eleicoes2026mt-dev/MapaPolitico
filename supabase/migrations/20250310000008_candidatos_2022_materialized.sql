-- Evita timeout: view candidatos_2022_mt sobre 720k+ linhas vira materialized view (pré-calculada).
-- Após importar dados em votacao_secao, rode: REFRESH MATERIALIZED VIEW candidatos_2022_mt;

-- Se o CSV foi importado com coluna "NM_VOTAVEL" (maiúsculo), copia para nm_votavel para a view usar
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'votacao_secao' AND column_name = 'NM_VOTAVEL'
  ) THEN
    EXECUTE 'UPDATE votacao_secao SET nm_votavel = "NM_VOTAVEL" WHERE "NM_VOTAVEL" IS NOT NULL';
  END IF;
END $$;

DROP VIEW IF EXISTS candidatos_2022_mt;

CREATE MATERIALIZED VIEW candidatos_2022_mt AS
SELECT DISTINCT ON (sq_candidato) sq_candidato, nm_votavel
FROM votacao_secao
WHERE ano_eleicao = 2022
  AND (sg_uf = 'MT' OR sg_uf IS NULL)
ORDER BY sq_candidato, nm_votavel;

CREATE UNIQUE INDEX ON candidatos_2022_mt (sq_candidato);

GRANT SELECT ON candidatos_2022_mt TO authenticated;
GRANT SELECT ON candidatos_2022_mt TO anon;

-- Índice para acelerar o REFRESH da materialized view
CREATE INDEX IF NOT EXISTS idx_votacao_secao_2022_mt ON votacao_secao (ano_eleicao, sg_uf)
  WHERE ano_eleicao = 2022 AND (sg_uf = 'MT' OR sg_uf IS NULL);
