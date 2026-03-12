-- Remove a tabela dados_tse: o app usa votacao_secao (e opcionalmente CSV local) para votos no mapa
DROP TABLE IF EXISTS dados_tse CASCADE;
