-- Campos para candidato: cargo, partido, número na urna (edição no "Meu perfil")

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS cargo TEXT,
  ADD COLUMN IF NOT EXISTS partido TEXT,
  ADD COLUMN IF NOT EXISTS numero_candidato TEXT;

COMMENT ON COLUMN profiles.cargo IS 'Cargo ao qual o candidato concorre: Deputado Federal, Deputado Estadual, Vereador, Prefeito, etc.';
COMMENT ON COLUMN profiles.partido IS 'Sigla do partido';
COMMENT ON COLUMN profiles.numero_candidato IS 'Número na urna';
