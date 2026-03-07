-- Perfis (auth.users vinculado) e Assessores

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  role app_role NOT NULL DEFAULT 'votante',
  invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  regional_polo_id UUID REFERENCES polos_regioes(id) ON DELETE SET NULL,
  avatar_url TEXT,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE assessores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  telefone TEXT,
  email TEXT,
  municipio_id UUID REFERENCES municipios(id) ON DELETE SET NULL,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_invited_by ON profiles(invited_by);
CREATE INDEX idx_profiles_regional_polo ON profiles(regional_polo_id);
CREATE INDEX idx_assessores_profile ON assessores(profile_id);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE TRIGGER assessores_updated_at BEFORE UPDATE ON assessores
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
