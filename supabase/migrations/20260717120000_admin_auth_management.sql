-- Funções administrativas para buscar e excluir usuários do sistema.
-- Acessíveis somente para candidato e assessores com grau_acesso = 1.
-- SECURITY DEFINER é necessário para acessar auth.users (schema restrito).

-- ─────────────────────────────────────────────────────────────────────────────
-- Buscar usuários (por nome ou e-mail)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_buscar_usuarios(pesquisa TEXT DEFAULT '')
RETURNS TABLE (
  uid          UUID,
  email        TEXT,
  nome         TEXT,
  papel        TEXT,
  ativo        BOOLEAN,
  criado_em    TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Apenas candidato ou assessor grau 1 podem chamar esta função.
  IF NOT (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'candidato')
    OR EXISTS (
      SELECT 1
        FROM public.profiles p
        JOIN public.assessores a ON a.profile_id = auth.uid()
       WHERE p.id = auth.uid()
         AND p.role = 'assessor'
         AND a.grau_acesso = 1
         AND a.ativo = true
    )
  ) THEN
    RAISE EXCEPTION 'Sem permissão para listar usuários.';
  END IF;

  RETURN QUERY
  SELECT
    au.id,
    au.email::TEXT,
    COALESCE(NULLIF(TRIM(p.full_name), ''), '—')   AS nome,
    COALESCE(p.role::TEXT, 'sem_perfil')             AS papel,
    COALESCE(p.ativo, false)                         AS ativo,
    au.created_at
  FROM auth.users au
  LEFT JOIN public.profiles p ON p.id = au.id
  WHERE
    pesquisa = ''
    OR au.email    ILIKE '%' || pesquisa || '%'
    OR p.full_name ILIKE '%' || pesquisa || '%'
  ORDER BY au.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_buscar_usuarios(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_buscar_usuarios(TEXT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Excluir usuário (remove auth.users → cascade apaga profiles e dados filhos)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_deletar_usuario(target_uid UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Verificar permissão do chamador.
  IF NOT (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'candidato')
    OR EXISTS (
      SELECT 1
        FROM public.profiles p
        JOIN public.assessores a ON a.profile_id = auth.uid()
       WHERE p.id = auth.uid()
         AND p.role = 'assessor'
         AND a.grau_acesso = 1
         AND a.ativo = true
    )
  ) THEN
    RAISE EXCEPTION 'Sem permissão para excluir usuários.';
  END IF;

  -- Impedir autoexclusão.
  IF target_uid = auth.uid() THEN
    RAISE EXCEPTION 'Não é possível excluir sua própria conta.';
  END IF;

  -- Impedir exclusão de outros candidatos.
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = target_uid AND role = 'candidato') THEN
    RAISE EXCEPTION 'Não é possível excluir um candidato pelo painel.';
  END IF;

  DELETE FROM auth.users WHERE id = target_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_deletar_usuario(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_deletar_usuario(UUID) TO authenticated;
