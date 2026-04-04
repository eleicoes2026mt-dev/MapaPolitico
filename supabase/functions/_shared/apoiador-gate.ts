// Lógica partilhada: quem pode convidar / reenviar convite a um apoiador.
// Usa a mesma regra que public.app_assessor_ids_do_candidato() (RLS) via RPC.
import { type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type ApoiadorRow = {
  id: string;
  assessor_id: string;
  profile_id: string | null;
  nome: string;
  email: string | null;
};

/** IDs em assessores.id da campanha do candidato (alinhado a app_assessor_ids_do_candidato / RLS). */
async function assessorIdsForCandidatoCampaign(
  supabaseAdmin: SupabaseClient,
  candidatoProfileId: string
): Promise<{ ids: string[]; error: string | null }> {
  const { data, error } = await supabaseAdmin.rpc('app_assessor_ids_for_candidato_profile', {
    p_candidato: candidatoProfileId,
  });
  if (error) {
    console.error('app_assessor_ids_for_candidato_profile', error);
    return { ids: [], error: error.message ?? String(error) };
  }
  const ids = (data ?? []) as string[];
  return { ids, error: null };
}

function isAssessorRowInCampaign(assessorRowId: string, campaignAssessorIds: string[]): boolean {
  const a = String(assessorRowId);
  return campaignAssessorIds.some((id) => String(id) === a);
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
    const { ids, error: rpcErr } = await assessorIdsForCandidatoCampaign(supabaseAdmin, callerId);
    if (rpcErr) {
      return {
        ok: false,
        status: 500,
        error:
          'Falha ao validar permissão da campanha. Confirme se a migração app_assessor_ids_for_candidato_profile foi aplicada no projeto.',
      };
    }
    if (isAssessorRowInCampaign(assessorIdOfApoiador, ids)) return { ok: true };
    return { ok: false, status: 403, error: 'Este apoiador não pertence à sua campanha' };
  }

  if (role === 'assessor') {
    const candidatoId = await resolveCandidatoIdFromUserProfile(supabaseAdmin, callerId);
    if (candidatoId) {
      const { ids, error: rpcErr } = await assessorIdsForCandidatoCampaign(supabaseAdmin, candidatoId);
      if (rpcErr) {
        return {
          ok: false,
          status: 500,
          error:
            'Falha ao validar permissão da campanha. Confirme se a migração app_assessor_ids_for_candidato_profile foi aplicada no projeto.',
        };
      }
      if (isAssessorRowInCampaign(assessorIdOfApoiador, ids)) return { ok: true };
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
