-- =============================================================================
-- LIMPEZA: apoiadores, votantes, assessores (+ dependências diretas)
-- =============================================================================
-- Execute no Supabase: SQL Editor → cole o bloco BEGIN…COMMIT (ou o script inteiro).
-- Requer permissão de escrita nas tabelas (use role postgres / service role, não o anon).
--
-- ATENÇÃO:
-- - Apaga TODOS os registros dessas tabelas no projeto (não filtra por campanha).
-- - O candidato perde a linha em `assessores` até recriar; perfis em `profiles` continuam.
-- - Faça backup se houver dados em produção.
--
-- Ordem: votantes → benfeitorias → aniversariantes (refs) → apoiadores → assessores
-- (apoiadores referencia assessores com ON DELETE RESTRICT — não pode apagar assessores antes.)
-- Se existir a tabela `responsavel_regiao` (migração 20250310000009), as linhas somem em CASCADE ao apagar assessores.
-- =============================================================================

BEGIN;

-- 1) Votantes (referem apoiadores e assessores)
DELETE FROM public.votantes;

-- 2) Benfeitorias ligadas a apoiadores (também CASCADE ao apagar apoiadores, mas é explícito)
DELETE FROM public.benfeitorias;

-- 3) Aniversariantes que apontam para essas entidades (sem FK, mas evita lixo órfão)
DELETE FROM public.aniversariantes
WHERE tipo_ref IN ('votante', 'apoiador', 'assessor');

-- 4) Apoiadores (dependem de assessores)
DELETE FROM public.apoiadores;

-- 5) Assessores (se `responsavel_regiao` existir no projeto, FK ON DELETE CASCADE apaga essas linhas aqui)
DELETE FROM public.assessores;

COMMIT;

-- Opcional: esvaziar auditoria de campanha (histórico de alterações; não é obrigatório para “travar”)
-- TRUNCATE TABLE public.campanha_audit_log;
