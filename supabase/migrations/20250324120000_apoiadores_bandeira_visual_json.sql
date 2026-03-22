-- Estilo completo da bandeira no mapa (cores, layout, iniciais, emoji) em JSON.

ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS bandeira_visual jsonb;

COMMENT ON COLUMN apoiadores.bandeira_visual IS 'JSON: cor1/cor2, layout, emoji, iniciais e estilo do texto (Flutter BandeiraVisual)';
