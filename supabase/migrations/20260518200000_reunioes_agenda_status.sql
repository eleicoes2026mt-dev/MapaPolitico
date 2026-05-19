-- Status da visita na agenda: agendado | realizada.
-- Só candidato ou assessor com grau_acesso = 1 pode definir/alterar; demais ficam em agendado.

ALTER TABLE public.reunioes
  ADD COLUMN IF NOT EXISTS agenda_status text NOT NULL DEFAULT 'agendado';

ALTER TABLE public.reunioes
  DROP CONSTRAINT IF EXISTS reunioes_agenda_status_check;

ALTER TABLE public.reunioes
  ADD CONSTRAINT reunioes_agenda_status_check
  CHECK (agenda_status IN ('agendado', 'realizada'));

COMMENT ON COLUMN public.reunioes.agenda_status IS
  'Estado da visita: agendado (padrão) ou realizada. Alteração só por candidato ou assessor grau 1.';

CREATE OR REPLACE FUNCTION public.reunioes_agenda_status_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pode boolean;
BEGIN
  pode := public.app_is_candidato() OR EXISTS (
    SELECT 1
    FROM public.assessores a
    INNER JOIN public.profiles p ON p.id = a.profile_id
    WHERE a.profile_id = auth.uid()
      AND COALESCE(a.grau_acesso, 2) = 1
      AND COALESCE(a.ativo, true)
      AND COALESCE(p.ativo, true)
  );

  IF TG_OP = 'INSERT' THEN
    IF NOT pode THEN
      NEW.agenda_status := 'agendado';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.agenda_status IS DISTINCT FROM OLD.agenda_status AND NOT pode THEN
      RAISE EXCEPTION 'Apenas o candidato ou assessor de grau 1 pode alterar o status da visita.';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reunioes_agenda_status_guard ON public.reunioes;
CREATE TRIGGER reunioes_agenda_status_guard
  BEFORE INSERT OR UPDATE ON public.reunioes
  FOR EACH ROW
  EXECUTE PROCEDURE public.reunioes_agenda_status_guard();

COMMENT ON FUNCTION public.reunioes_agenda_status_guard() IS
  'Força agenda_status=agendado em INSERT por quem não é gestor; bloqueia mudança de status em UPDATE.';
