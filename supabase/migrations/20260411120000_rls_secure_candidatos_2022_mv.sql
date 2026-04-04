-- candidatos_2022_mt é uma MATERIALIZED VIEW: o PostgreSQL não permite ENABLE ROW LEVEL SECURITY
-- sobre MVs, por isso o Supabase mostra «UNRESTRICTED». O controlo de acesso faz-se com GRANT.
-- Remove leitura anónima (role anon) para alinhar a votacao_secao / perfil (só authenticated).
-- O app lê esta MV em candidatos2022MtProvider com sessão autenticada.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_matviews
    WHERE schemaname = 'public' AND matviewname = 'candidatos_2022_mt'
  ) THEN
    REVOKE SELECT ON TABLE public.candidatos_2022_mt FROM anon;
    GRANT SELECT ON TABLE public.candidatos_2022_mt TO authenticated;
    EXECUTE format(
      'COMMENT ON MATERIALIZED VIEW public.candidatos_2022_mt IS %L',
      'Candidatos 2022 MT (TSE). SELECT apenas para authenticated; MV não suporta RLS no PostgreSQL.'
    );
  END IF;
END $$;
