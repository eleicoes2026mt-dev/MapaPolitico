-- Personalização visual do apoiador no mapa (iniciais, cores, emoji).

ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_iniciais text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_cor_primaria text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_cor_secundaria text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_simbolo text;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_emoji text;

COMMENT ON COLUMN apoiadores.bandeira_iniciais IS 'Até 3 caracteres exibidos no marcador do mapa';
COMMENT ON COLUMN apoiadores.bandeira_cor_primaria IS 'Cor principal do marcador (hex #RRGGBB)';
COMMENT ON COLUMN apoiadores.bandeira_cor_secundaria IS 'Cor secundária opcional (hex)';
COMMENT ON COLUMN apoiadores.bandeira_simbolo IS 'Identificador opcional de ícone/símbolo (futuro)';
COMMENT ON COLUMN apoiadores.bandeira_emoji IS 'Emoji opcional no tooltip/marcador';
