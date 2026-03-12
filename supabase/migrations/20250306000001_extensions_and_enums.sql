-- CampanhaMT - Gestão Eleitoral MT
-- Extensões e tipos enum (idempotente: não falha se já existirem)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN
  CREATE TYPE app_role AS ENUM ('candidato', 'assessor', 'apoiador', 'votante');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE tipo_pessoa AS ENUM ('PF', 'PJ');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE abrangencia_voto AS ENUM ('Individual', 'Familiar');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE status_benfeitoria AS ENUM ('em_andamento', 'concluida', 'planejada');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE tipo_benfeitoria AS ENUM ('Reforma', 'Obra', 'Doação', 'Evento', 'Outro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE escopo_mensagem AS ENUM ('global', 'polo', 'cidade', 'performance', 'reuniao');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE status_performance AS ENUM ('critico', 'abaixo_meta', 'em_evolucao', 'meta_atingida', 'alta_performance');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
