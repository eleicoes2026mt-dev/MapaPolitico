-- Legado: votos prometidos pelo apoiador na última eleição (opcional)
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS votos_prometidos_ultima_eleicao INTEGER;
COMMENT ON COLUMN apoiadores.votos_prometidos_ultima_eleicao IS 'Votos prometidos por este apoiador na última eleição (legado)';
