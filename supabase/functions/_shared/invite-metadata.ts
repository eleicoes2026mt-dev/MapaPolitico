// Metadados de convite → user_metadata → templates Auth (variável {{ .Data }} no painel Supabase).
import { type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveCandidatoIdFromUserProfile } from "./apoiador-gate.ts";

export async function displayNameForProfile(
  admin: SupabaseClient,
  profileId: string,
): Promise<string> {
  const { data } = await admin.from("profiles").select("full_name, email").eq("id", profileId)
    .maybeSingle();
  const row = data as { full_name?: string | null; email?: string | null } | null;
  if (!row) return "Campanha eleitoral";
  const n = (row.full_name ?? "").trim();
  if (n.length > 0) return n;
  const e = (row.email ?? "").trim();
  return e.length > 0 ? e : "Campanha eleitoral";
}

/** Nome do candidato para o texto do e-mail (quem convida apoiador pode ser assessor). */
export async function candidatoNomeForApoiadorInvite(
  admin: SupabaseClient,
  callerId: string,
  callerRole: string,
): Promise<string> {
  if (callerRole === "candidato") {
    return displayNameForProfile(admin, callerId);
  }
  const candidatoId = await resolveCandidatoIdFromUserProfile(admin, callerId);
  if (candidatoId) return displayNameForProfile(admin, candidatoId);
  return displayNameForProfile(admin, callerId);
}

export function inviteUserMetadataAssessor(params: {
  convidadoNome: string;
  candidatoNome: string;
}): Record<string, string> {
  const { convidadoNome, candidatoNome } = params;
  return {
    full_name: convidadoNome,
    role: "assessor",
    invite_kind: "assessor",
    candidato_nome: candidatoNome,
    convidante_nome: candidatoNome,
    convidante_papel: "candidato",
  };
}

export function inviteUserMetadataApoiador(params: {
  convidadoNome: string;
  candidatoNome: string;
  convidanteNome: string;
  convidantePapel: "candidato" | "assessor";
}): Record<string, string> {
  return {
    full_name: params.convidadoNome,
    role: "apoiador",
    invite_kind: "apoiador",
    candidato_nome: params.candidatoNome,
    convidante_nome: params.convidanteNome,
    convidante_papel: params.convidantePapel,
  };
}
