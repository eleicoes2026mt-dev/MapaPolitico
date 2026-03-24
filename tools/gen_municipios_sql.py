"""Gera SQL para inserir todos os municípios MT (chaves do mapa) na tabela municipios."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
dart = (root / "lib/features/mapa/data/mt_municipios_coords.dart").read_text(encoding="utf-8")
keys = re.findall(r"'([^']+)': LatLng", dart)


def title_from_key(k: str) -> str:
    parts = k.split(" ")
    out = []
    for p in parts:
        if not p:
            continue
        if "'" in p:
            out.append(p[0].upper() + p[1:].lower())
        else:
            out.append(p[0].upper() + p[1:].lower() if len(p) > 1 else p.upper())
    return " ".join(out)


def norm_sql(k: str) -> str:
    t = k.lower()
    repl = (
        ("á", "a"), ("à", "a"), ("â", "a"), ("ã", "a"), ("ä", "a"),
        ("é", "e"), ("è", "e"), ("ê", "e"), ("ë", "e"),
        ("í", "i"), ("ì", "i"), ("î", "i"), ("ï", "i"),
        ("ó", "o"), ("ò", "o"), ("ô", "o"), ("õ", "o"), ("ö", "o"),
        ("ú", "u"), ("ù", "u"), ("û", "u"), ("ü", "u"),
        ("ç", "c"),
    )
    for a, b in repl:
        t = t.replace(a, b)
    return t


def esc(s: str) -> str:
    return s.replace("'", "''")


rows = []
for k in sorted(keys):
    nome = esc(title_from_key(k))
    nn = esc(norm_sql(k))
    rows.append(f"  ('{nome}', '{nn}')")

sql = f"""-- Municípios MT alinhados ao mapa do app (chaves em mt_municipios_coords.dart).
-- Atribui polo Sinop por omissão; registros já existentes não são alterados.
INSERT INTO municipios (nome, nome_normalizado, polo_id, sub_regiao_cuiaba)
SELECT v.nome, v.nome_normalizado, p.id, NULL
FROM (
VALUES
{",\n".join(rows)}
) AS v(nome, nome_normalizado)
CROSS JOIN LATERAL (SELECT id FROM polos_regioes WHERE nome = 'Sinop' LIMIT 1) AS p(id)
ON CONFLICT (nome_normalizado) DO NOTHING;
"""

out = root / "supabase/migrations/20250327120000_municipios_mt_mapa_completo.sql"
out.write_text(sql, encoding="utf-8")
print(f"Wrote {len(keys)} rows to {out}")
