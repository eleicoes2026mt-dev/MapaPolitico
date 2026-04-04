// Lógica partilhada: quem pode convidar / reenviar convite a um apoiador.
// Usa public.edge_can_manage_apoiador_invite (SECURITY DEFINER): não depende de RLS nem de RPC extra no PostgREST.
import { type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type ApoiadorRow = {
  id: string;
  assessor_id: string;
  profile_id: string | null;
  nome: string;
  email: string | null;
};

/** Sobe invited_by até encontrar perfil com role candidato (outros módulos). */
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

type GatePayload = { ok?: boolean; code?: string };

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

  const { data: raw, error: rpcErr } = await supabaseAdmin.rpc('edge_can_manage_apoiador_invite', {
    p_caller: callerId,
    p_apoiador: apoiador.id,
  });

  if (rpcErr) {
    console.error('edge_can_manage_apoiador_invite', rpcErr);
    return {
      ok: false,
      status: 500,
      error:
        'Falha ao validar permissão. Rode a migração edge_can_manage_apoiador_invite no SQL do Supabase e faça redeploy das Edge Functions.',
    };
  }

  const g = raw as GatePayload | null;
  if (g?.ok === true) return { ok: true };

  const code = (g?.code ?? '').trim();
  switch (code) {
    case 'no_profile':
      return { ok: false, status: 403, error: 'Perfil não encontrado' };
    case 'no_apoiador':
      return { ok: false, status: 404, error: 'Apoiador não encontrado ou foi excluído da campanha' };
    case 'not_campaign':
      return { ok: false, status: 403, error: 'Este apoiador não pertence à sua campanha' };
    case 'strict_assessor':
      return { ok: false, status: 403, error: strictMsg };
    case 'forbidden_role':
      return { ok: false, status: 403, error: forbiddenRoleMsg };
    default:
      return {
        ok: false,
        status: 500,
        error:
          'Resposta inválida do gate de convite. Confirme a migração edge_can_manage_apoiador_invite e o redeploy.',
      };
  }
}
