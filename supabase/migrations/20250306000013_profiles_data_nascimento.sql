-- Data de nascimento no perfil

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS data_nascimento DATE;

COMMENT ON COLUMN profiles.data_nascimento IS 'Data de nascimento do usuário';
