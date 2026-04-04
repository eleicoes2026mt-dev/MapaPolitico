-- Distingue no mapa: azul (cadastro pelo candidato) vs roxo+azul (cadastro por assessor).
ALTER TABLE public.votantes
  ADD COLUMN IF NOT EXISTS cadastrado_pelo_candidato BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.votantes.cadastrado_pelo_candidato IS
  'TRUE quando o registro foi criado com o candidato logado (marcador azul no mapa).';
