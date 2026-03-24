-- Promover um usuário a Candidato (role = candidato) e garantir linha em `assessores`
-- (necessária para RLS / árvore da campanha: auth.assessor_ids_do_candidato).
--
-- Execute no SQL Editor do Supabase com role que ignore RLS (postgres / service role via SQL).
--
-- Regra do app: só pode existir UM candidato por base (a Edge Function promover-candidato bloqueia
-- se já houver outro). Se já existir candidato, rebaixe-o antes ou ajuste o UPDATE abaixo.

-- 1) Ver situação atual
SELECT id, email, full_name, role
FROM public.profiles
WHERE role = 'candidato'
   OR email ILIKE 'eleicoes2026mt@gmail.com';

-- 2) Opcional: se já existir OUTRO candidato e você quiser trocar, rebaixe o antigo:
-- UPDATE public.profiles
-- SET role = 'votante'::app_role, updated_at = now()
-- WHERE id = 'UUID_DO_CANDIDATO_ANTIGO';

-- 3) Promover o usuário pelo e-mail (ajuste o e-mail se for outro)
UPDATE public.profiles
SET
  role = 'candidato'::app_role,
  updated_at = now()
WHERE email = 'eleicoes2026mt@gmail.com';

-- 4) Garantir registro em assessores para o candidato (um por profile_id)
INSERT INTO public.assessores (profile_id, nome, email, telefone, municipio_id, ativo)
SELECT
  p.id,
  COALESCE(NULLIF(trim(p.full_name), ''), 'Candidato'),
  p.email,
  p.phone,
  NULL, -- municipio_id: preencher depois no app se necessário
  true
FROM public.profiles p
WHERE p.email = 'eleicoes2026mt@gmail.com'
  AND NOT EXISTS (
    SELECT 1 FROM public.assessores a WHERE a.profile_id = p.id
  );
