-- Coordenadas do ponto exato da visita (mapa / Waze / Google Maps)
ALTER TABLE reunioes
  ADD COLUMN IF NOT EXISTS local_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS local_lng DOUBLE PRECISION;

COMMENT ON COLUMN reunioes.local_lat IS 'Latitude do local da reunião (picker no mapa).';
COMMENT ON COLUMN reunioes.local_lng IS 'Longitude do local da reunião (picker no mapa).';

-- Confirmação de presença (apoiador da cidade ou assessor)
CREATE TABLE IF NOT EXISTS reunioes_presenca (
  reuniao_id UUID NOT NULL REFERENCES reunioes(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  confirmado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (reuniao_id, profile_id)
);

CREATE INDEX IF NOT EXISTS idx_reunioes_presenca_profile ON reunioes_presenca(profile_id);
CREATE INDEX IF NOT EXISTS idx_reunioes_presenca_reuniao ON reunioes_presenca(reuniao_id);

ALTER TABLE reunioes_presenca ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reunioes_presenca_read" ON reunioes_presenca
  FOR SELECT TO authenticated USING (true);

-- PostgREST: bloquear INSERT direto; usar apenas registrar_presenca_visita().
CREATE POLICY "reunioes_presenca_insert_denied" ON reunioes_presenca
  FOR INSERT TO authenticated
  WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.registrar_presenca_visita(p_reuniao_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mun_reuniao UUID;
  v_visivel BOOLEAN;
  v_mun_apoiador UUID;
  v_role TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Não autenticado';
  END IF;

  SELECT r.municipio_id, COALESCE(r.visivel_apoiadores, true)
  INTO v_mun_reuniao, v_visivel
  FROM reunioes r
  WHERE r.id = p_reuniao_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Visita não encontrada';
  END IF;

  IF NOT v_visivel THEN
    RAISE EXCEPTION 'Esta visita não está visível para apoiadores.';
  END IF;

  SELECT role INTO v_role FROM profiles WHERE id = auth.uid();

  IF v_role = 'apoiador' THEN
    IF v_mun_reuniao IS NULL THEN
      RAISE EXCEPTION 'Visita sem cidade definida.';
    END IF;
    SELECT ap.municipio_id INTO v_mun_apoiador
    FROM apoiadores ap
    WHERE ap.profile_id = auth.uid()
      AND COALESCE(ap.ativo, true)
    LIMIT 1;
    IF v_mun_apoiador IS NULL OR v_mun_reuniao IS DISTINCT FROM v_mun_apoiador THEN
      RAISE EXCEPTION 'Esta visita não é da sua cidade.';
    END IF;
  ELSIF v_role = 'assessor' THEN
    IF public.app_my_assessor_id() IS NULL THEN
      RAISE EXCEPTION 'Assessor não identificado.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Apenas apoiador ou assessor podem confirmar presença.';
  END IF;

  INSERT INTO reunioes_presenca (reuniao_id, profile_id)
  VALUES (p_reuniao_id, auth.uid())
  ON CONFLICT (reuniao_id, profile_id) DO UPDATE SET confirmado_em = now();
END;
$$;

COMMENT ON FUNCTION public.registrar_presenca_visita IS 'Apoiador (mesma cidade) ou assessor ativo confirma presença na visita.';

GRANT EXECUTE ON FUNCTION public.registrar_presenca_visita(UUID) TO authenticated;
