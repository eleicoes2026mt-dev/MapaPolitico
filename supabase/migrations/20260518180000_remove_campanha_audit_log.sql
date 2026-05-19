-- Remove auditoria campanha_audit_log (UI e escritas) para aliviar o banco.

-- 1) Triggers de audit (antes de alterar RPCs que fazem DML nas mesmas tabelas)
DROP TRIGGER IF EXISTS assessores_audit ON public.assessores;
DROP TRIGGER IF EXISTS apoiadores_audit ON public.apoiadores;
DROP TRIGGER IF EXISTS votantes_audit ON public.votantes;
DROP TRIGGER IF EXISTS benfeitorias_audit ON public.benfeitorias;
DROP TRIGGER IF EXISTS mensagens_audit ON public.mensagens;
DROP TRIGGER IF EXISTS reunioes_audit ON public.reunioes;
DROP TRIGGER IF EXISTS profiles_audit_role_ativo ON public.profiles;

DROP FUNCTION IF EXISTS public.trg_audit_assessores() CASCADE;
DROP FUNCTION IF EXISTS public.trg_audit_apoiadores() CASCADE;
DROP FUNCTION IF EXISTS public.trg_audit_votantes() CASCADE;
DROP FUNCTION IF EXISTS public.trg_audit_benfeitorias() CASCADE;
DROP FUNCTION IF EXISTS public.trg_audit_mensagens() CASCADE;
DROP FUNCTION IF EXISTS public.trg_audit_reunioes() CASCADE;
DROP FUNCTION IF EXISTS public.trg_audit_profiles_role_ativo() CASCADE;

-- 2) RPC de exclusão de apoiador: deixa de gravar em audit
CREATE OR REPLACE FUNCTION public.candidato_excluir_apoiador(p_apoiador_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row apoiadores%ROWTYPE;
  v_prof UUID;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato pode excluir apoiadores.';
  END IF;

  SELECT * INTO v_row FROM apoiadores WHERE id = p_apoiador_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Apoiador não encontrado.';
  END IF;

  IF NOT (v_row.assessor_id IN (SELECT public.app_assessor_ids_do_candidato())) THEN
    RAISE EXCEPTION 'Apoiador não pertence à sua campanha.';
  END IF;

  IF v_row.excluido_em IS NOT NULL THEN
    RAISE EXCEPTION 'Este apoiador já foi excluído.';
  END IF;

  v_prof := v_row.profile_id;

  IF v_prof IS NOT NULL THEN
    UPDATE profiles SET ativo = false WHERE id = v_prof;
  END IF;

  UPDATE apoiadores
  SET excluido_em = now(), profile_id = NULL, updated_at = now()
  WHERE id = p_apoiador_id;
END;
$$;

COMMENT ON FUNCTION public.candidato_excluir_apoiador IS
  'Candidato: marca apoiador como excluído (soft), remove vínculo de login e desativa o perfil.';

-- 3) Restauração pelo histórico descontinuada
CREATE OR REPLACE FUNCTION public.restaurar_registro_audit(p_log_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'O histórico de alterações foi descontinuado. A restauração por log não está mais disponível.';
END;
$$;

COMMENT ON FUNCTION public.restaurar_registro_audit(UUID) IS
  'Descontinuado junto com campanha_audit_log.';

-- 4) Função de log e auxiliares só usadas pelos triggers removidos
DROP FUNCTION IF EXISTS public.log_campanha_audit_event(UUID, UUID, TEXT, UUID, TEXT, JSONB, JSONB) CASCADE;

DROP FUNCTION IF EXISTS public.candidato_profile_id_para_assessor(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.candidato_profile_id_para_votante(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.candidato_profile_id_para_benfeitoria(UUID) CASCADE;

-- 5) Tabela de histórico
DROP POLICY IF EXISTS campanha_audit_candidato_select ON public.campanha_audit_log;
DROP POLICY IF EXISTS campanha_audit_gestor_select ON public.campanha_audit_log;

DROP TABLE IF EXISTS public.campanha_audit_log CASCADE;
