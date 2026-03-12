-- Vincula o candidato ao registro na eleição 2022 (votacao_secao) para exibir votos no mapa
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS sq_candidato_tse_2022 BIGINT;

COMMENT ON COLUMN profiles.sq_candidato_tse_2022 IS 'sq_candidato na tabela votacao_secao (eleição 2022) para exibir votos por cidade no mapa';

-- View com candidatos distintos da eleição 2022 (MT) para o dropdown no perfil
CREATE OR REPLACE VIEW candidatos_2022_mt AS
SELECT DISTINCT ON (sq_candidato) sq_candidato, nm_votavel
FROM votacao_secao
WHERE ano_eleicao = 2022
  AND (sg_uf = 'MT' OR sg_uf IS NULL)
ORDER BY sq_candidato, nm_votavel;

-- Leitura na view e na tabela para usuários autenticados (RLS)
ALTER TABLE votacao_secao ENABLE ROW LEVEL SECURITY;

CREATE POLICY "votacao_secao_read_authenticated" ON votacao_secao
  FOR SELECT TO authenticated USING (true);

GRANT SELECT ON candidatos_2022_mt TO authenticated;
GRANT SELECT ON candidatos_2022_mt TO anon;
