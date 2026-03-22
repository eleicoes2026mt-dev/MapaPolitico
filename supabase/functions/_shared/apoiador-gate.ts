// Lógica partilhada: quem pode convidar / reenviar convite a um apoiador.
import { type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type ApoiadorRow = {
  id: string;
  assessor_id: string;
  profile_id: string | null;
  nome: string;
  email: string | null;
};

/** [candidatoId, ...perfis com invited_by = candidatoId] — igual à regra do candidato na UI. */
export async function getCandidatoTeamProfileIds(
  supabaseAdmin: SupabaseClient,
  candidatoId: string
): Promise<string[]> {
  const { data: inv } = await supabaseAdmin.from('profiles').select('id').eq('invited_by', candidatoId);
  return [candidatoId, ...((inv ?? []) as { id: string }[]).map((x) => x.id)];
}

/** Sobe invited_by até encontrar perfil com role candidato. */
export async function resolveCandidatoIdFromUserProfile(
  supabaseAdmin: SupabaseClient,
  userProfileId: string
): Promise<string | null> {
  let current: string | null = userProfileId;
  for (let depth = 0; depth < 40 && current; depth++) {
    const { data: p, error } = await supabaseAdmin
      .from('profiles')
      .select('id, role, invited_by')
      .eq('id', current)
      .single();
    if (error || !p) return null;
    const row = p as { id: string; role: string; invited_by: string | null };
    if (row.role === 'candidato') return row.id;
    current = row.invited_by;
  }
  return null;
}

export async function apoiadorAssessorIsInProfileSet(
  supabaseAdmin: SupabaseClient,
  assessorIdOfApoiador: string,
  profileIds: string[]
): Promise<boolean> {
  if (profileIds.length === 0) return false;
  const { data: row } = await supabaseAdmin
    .from('assessores')
    .select('id')
    .eq('id', assessorIdOfApoiador)
    .in('profile_id', profileIds)
    .maybeSingle();
  return !!row;
}

export type ApoiadorGateOptions = {
  /** Mensagem quando só o assessor «dono» pode agir (sem cadeia até candidato). */
  strictAssessorMessage?: string;
  /** Quem não é candidato nem assessor. */
  forbiddenRoleMessage?: string;
};

export async function assertCanManageApoiador(
  supabaseAdmin: SupabaseClient,
  callerId: string,
  apoiador: ApoiadorRow,
  options: ApoiadorGateOptions = {}
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const strictMsg =
    options.strictAssessorMessage ?? 'Apenas o assessor responsável pode convidar este apoiador';
  const forbiddenRoleMsg =
    options.forbiddenRoleMessage ?? 'Apenas candidato ou assessor podem enviar convite ao apoiador';
  const { data: caller, error: ce } = await supabaseAdmin.from('profiles').select('role').eq('id', callerId).single();
  if (ce || !caller) return { ok: false, status: 403, error: 'Perfil não encontrado' };

  const role = (caller as { role: string }).role;
  const assessorIdOfApoiador = apoiador.assessor_id;

  if (role === 'candidato') {
    const teamIds = await getCandidatoTeamProfileIds(supabaseAdmin, callerId);
    const ok = await apoiadorAssessorIsInProfileSet(supabaseAdmin, assessorIdOfApoiador, teamIds);
    if (!ok) return { ok: false, status: 403, error: 'Este apoiador não pertence à sua campanha' };
    return { ok: true };
  }

  if (role === 'assessor') {
    const candidatoId = await resolveCandidatoIdFromUserProfile(supabaseAdmin, callerId);
    if (candidatoId) {
      const teamIds = await getCandidatoTeamProfileIds(supabaseAdmin, candidatoId);
      const inTeam = await apoiadorAssessorIsInProfileSet(supabaseAdmin, assessorIdOfApoiador, teamIds);
      if (inTeam) return { ok: true };
      return { ok: false, status: 403, error: 'Este apoiador não pertence à sua campanha' };
    }
    // Perfil assessor sem cadeia até candidato: mantém regra antiga (só o responsável direto).
    const { data: a } = await supabaseAdmin.from('assessores').select('id').eq('profile_id', callerId).maybeSingle();
    if (!a || (a as { id: string }).id !== assessorIdOfApoiador) {
      return { ok: false, status: 403, error: strictMsg };
    }
    return { ok: true };
  }

  return { ok: false, status: 403, error: forbiddenRoleMsg };
}
