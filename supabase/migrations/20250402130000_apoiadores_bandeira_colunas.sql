-- Adiciona todas as colunas de bandeira que podem estar faltando (idempotente).
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_visual        jsonb;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_iniciais      text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_cor_primaria  text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_cor_secundaria text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_simbolo       text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_emoji         text;
