-- Nomes e cores customizadas das regiões do mapa (compartilhados entre todos os usuários)

CREATE TABLE mapa_regioes_custom (
  cd_rgint TEXT PRIMARY KEY,
  nome TEXT,
  cor_hex TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mapa_regioes_custom_updated ON mapa_regioes_custom(updated_at);

CREATE TRIGGER mapa_regioes_custom_updated_at
  BEFORE UPDATE ON mapa_regioes_custom
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

ALTER TABLE mapa_regioes_custom ENABLE ROW LEVEL SECURITY;

-- Todos os autenticados podem ler (ver as customizações)
CREATE POLICY "mapa_regioes_custom_select" ON mapa_regioes_custom
  FOR SELECT TO authenticated USING (true);

-- Todos os autenticados podem inserir/atualizar (qualquer um da campanha pode editar)
CREATE POLICY "mapa_regioes_custom_insert" ON mapa_regioes_custom
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "mapa_regioes_custom_update" ON mapa_regioes_custom
  FOR UPDATE TO authenticated USING (true);

COMMENT ON TABLE mapa_regioes_custom IS 'Nomes e cores customizados das regiões do mapa MT; compartilhado entre todos os usuários.';
