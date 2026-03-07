-- Polos regionais MT (5 polos IBGE 2021) + sub-regiões Cuiabá

CREATE TABLE polos_regioes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome TEXT NOT NULL UNIQUE,
  sub_regiao TEXT, -- NULL para polos; 'Norte'|'Sul'|'Leste'|'Oeste' apenas para Cuiabá
  descricao TEXT,
  cor_hex TEXT DEFAULT '#1976D2',
  ordem SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE municipios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome TEXT NOT NULL,
  nome_normalizado TEXT NOT NULL,
  codigo_ibge TEXT,
  polo_id UUID NOT NULL REFERENCES polos_regioes(id) ON DELETE RESTRICT,
  sub_regiao_cuiaba TEXT, -- 'Norte'|'Sul'|'Leste'|'Oeste' quando polo = Cuiabá
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(nome_normalizado)
);

CREATE INDEX idx_municipios_polo ON municipios(polo_id);
CREATE INDEX idx_municipios_nome ON municipios(nome_normalizado);

-- Inserir os 5 polos
INSERT INTO polos_regioes (nome, sub_regiao, descricao, cor_hex, ordem) VALUES
  ('Cuiabá', NULL, 'Centro-Sul - 30 municípios', '#2196F3', 1),
  ('Rondonópolis', NULL, 'Sudeste - 18 municípios', '#F44336', 2),
  ('Sinop', NULL, 'Norte - 43 municípios', '#4CAF50', 3),
  ('Barra do Garças', NULL, 'Leste - 30 municípios', '#FF9800', 4),
  ('Cáceres', NULL, 'Sudoeste/Oeste - 41 municípios', '#9C27B0', 5);

-- Sub-regiões de Cuiabá (como registros auxiliares ou usar apenas em municipios.sub_regiao_cuiaba)
-- Municípios serão inseridos via seed ou outra migration; aqui só a estrutura.

COMMENT ON TABLE polos_regioes IS '5 polos regionais MT + sub-regiões Cuiabá (Norte,Sul,Leste,Oeste)';
COMMENT ON TABLE municipios IS 'Municípios MT com polo e sub-região (Cuiabá)';
