-- Tabelas incluídas na publicação supabase_realtime para o app invalidar listas ao vivo.
-- Idempotente: ignora se já estiver publicada.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'apoiadores'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.apoiadores;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'votantes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.votantes;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'benfeitorias'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.benfeitorias;
  END IF;
END $$;
