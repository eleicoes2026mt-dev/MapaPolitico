-- CampanhaMT - Gestão Eleitoral MT
-- Extensões e tipos enum

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Roles da hierarquia
CREATE TYPE app_role AS ENUM ('candidato', 'assessor', 'apoiador', 'votante');

-- Tipo de pessoa (apoiador)
CREATE TYPE tipo_pessoa AS ENUM ('PF', 'PJ');

-- Abrangência do votante
CREATE TYPE abrangencia_voto AS ENUM ('Individual', 'Familiar');

-- Status de benfeitoria
CREATE TYPE status_benfeitoria AS ENUM ('em_andamento', 'concluida', 'planejada');

-- Tipo de benfeitoria
CREATE TYPE tipo_benfeitoria AS ENUM ('Reforma', 'Obra', 'Doação', 'Evento', 'Outro');

-- Escopo de mensagem
CREATE TYPE escopo_mensagem AS ENUM ('global', 'polo', 'cidade', 'performance', 'reuniao');

-- Status de performance (para estratégia)
CREATE TYPE status_performance AS ENUM ('critico', 'abaixo_meta', 'em_evolucao', 'meta_atingida', 'alta_performance');
