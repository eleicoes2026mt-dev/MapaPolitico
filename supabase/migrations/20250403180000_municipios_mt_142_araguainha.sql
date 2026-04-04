-- MT: 142 municípios (IBGE). Corrige "Araguanta" → Araguainha e insere os 4 faltantes.

UPDATE municipios
SET nome = 'Araguainha',
    nome_normalizado = 'araguainha'
WHERE nome_normalizado = 'araguanta'
   OR nome ILIKE 'Araguanta';

INSERT INTO municipios (nome, nome_normalizado, polo_id)
SELECT 'Boa Esperança do Norte', 'boa esperanca do norte', id
FROM polos_regioes WHERE nome = 'Sinop' LIMIT 1
ON CONFLICT (nome_normalizado) DO NOTHING;

INSERT INTO municipios (nome, nome_normalizado, polo_id)
SELECT 'Pontal do Araguaia', 'pontal do araguaia', id
FROM polos_regioes WHERE nome = 'Barra do Garças' LIMIT 1
ON CONFLICT (nome_normalizado) DO NOTHING;

INSERT INTO municipios (nome, nome_normalizado, polo_id)
SELECT 'Ponte Branca', 'ponte branca', id
FROM polos_regioes WHERE nome = 'Barra do Garças' LIMIT 1
ON CONFLICT (nome_normalizado) DO NOTHING;

INSERT INTO municipios (nome, nome_normalizado, polo_id)
SELECT 'Vila Bela da Santíssima Trindade', 'vila bela da santissima trindade', id
FROM polos_regioes WHERE nome = 'Cáceres' LIMIT 1
ON CONFLICT (nome_normalizado) DO NOTHING;
