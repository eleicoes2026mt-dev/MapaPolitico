-- Seed: municípios principais MT por polo (referência IBGE - principais cidades)

-- IDs dos polos (assumindo ordem de inserção)
-- Cuiabá, Rondonópolis, Sinop, Barra do Garças, Cáceres

INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Cuiabá', 'cuiaba', id, 'Sul' FROM polos_regioes WHERE nome = 'Cuiabá' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Várzea Grande', 'varzea grande', id, 'Oeste' FROM polos_regioes WHERE nome = 'Cuiabá' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Rondonópolis', 'rondonopolis', id, NULL FROM polos_regioes WHERE nome = 'Rondonópolis' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Sinop', 'sinop', id, NULL FROM polos_regioes WHERE nome = 'Sinop' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Sorriso', 'sorriso', id, NULL FROM polos_regioes WHERE nome = 'Sinop' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Lucas do Rio Verde', 'lucas do rio verde', id, NULL FROM polos_regioes WHERE nome = 'Sinop' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Campo Verde', 'campo verde', id, 'Leste' FROM polos_regioes WHERE nome = 'Cuiabá' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Primavera do Leste', 'primavera do leste', id, 'Leste' FROM polos_regioes WHERE nome = 'Cuiabá' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Barra do Garças', 'barra do garcas', id, NULL FROM polos_regioes WHERE nome = 'Barra do Garças' LIMIT 1;
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT 'Cáceres', 'caceres', id, NULL FROM polos_regioes WHERE nome = 'Cáceres' LIMIT 1;

-- Inserir metas regionais iniciais (distribuição %)
INSERT INTO metas_regionais (polo_id, meta_votos, percentual_distribuicao)
SELECT id, 15000, 30.0 FROM polos_regioes WHERE nome = 'Cuiabá' LIMIT 1
ON CONFLICT (polo_id) DO NOTHING;
INSERT INTO metas_regionais (polo_id, meta_votos, percentual_distribuicao)
SELECT id, 9000, 18.0 FROM polos_regioes WHERE nome = 'Rondonópolis' LIMIT 1
ON CONFLICT (polo_id) DO NOTHING;
INSERT INTO metas_regionais (polo_id, meta_votos, percentual_distribuicao)
SELECT id, 12500, 25.0 FROM polos_regioes WHERE nome = 'Sinop' LIMIT 1
ON CONFLICT (polo_id) DO NOTHING;
INSERT INTO metas_regionais (polo_id, meta_votos, percentual_distribuicao)
SELECT id, 7500, 15.0 FROM polos_regioes WHERE nome = 'Barra do Garças' LIMIT 1
ON CONFLICT (polo_id) DO NOTHING;
INSERT INTO metas_regionais (polo_id, meta_votos, percentual_distribuicao)
SELECT id, 6000, 12.0 FROM polos_regioes WHERE nome = 'Cáceres' LIMIT 1
ON CONFLICT (polo_id) DO NOTHING;
