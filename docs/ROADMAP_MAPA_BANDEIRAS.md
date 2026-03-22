# Roadmap: mapa, bandeiras, benfeitorias, promover votante

## Implementado (março 2025)

### SQL (migrações Supabase)

- `20250323120000_benfeitorias_agg_por_municipio.sql` — função `benfeitorias_agg_por_municipio()` (SECURITY INVOKER, RLS).
- `20250323120001_promover_votante_para_apoiador.sql` — RPC `promover_votante_para_apoiador(p_votante_id)` (candidato/assessor da campanha).
- `20250323120002_apoiadores_bandeira_mapa.sql` — colunas `bandeira_*` em `apoiadores`.

### App

- **Filtros no mapa** (tela Mapa): cidade, região intermediária (5101–5105), rede por apoiador (candidato/assessor), top N municípios por quantidade de benfeitorias. Providers: `mapa_filtros_provider`, `mapa_camadas_filtradas_provider`, `municipio_cd_rgint_provider`, `benfeitorias_agg_provider`.
- **Promover votante → apoiador:** ícone na lista/tabela de votantes (candidato/assessor); chama RPC; exige município e `apoiador_id` nulo no votante.
- **Bandeira:** apoiador edita em **Meu perfil** (iniciais, cor hex, emoji); marcadores na web usam `MapaMarcadorCidade` (ArcGIS: cor no círculo).

### Ainda em aberto / melhorias

- Símbolo Material/`bandeira_simbolo` no marcador (campo já existe no banco).
- Votantes herdarem visual do apoiador no mesmo município (hoje a bandeira vem do primeiro apoiador com dados na cidade).
- KPIs globais no dashboard espelhando o mapa.

---

## Referência histórica

- **Apoiador** não vê menu/rota **Apoiadores**; só **Votantes** (filtrados ao `apoiador_id` dele), **Mapa** e **Perfil**.
- **Candidato / assessor**: painel **Apoiadores** com indicadores por assessor.

Ordem seguida na entrega: **filtros mapa** → **promover votante** → **bandeira**.
