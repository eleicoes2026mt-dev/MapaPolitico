// Candidato ou assessor convida apoiador por e-mail (perfil apoiador + vínculo em apoiadores.profile_id).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type ApoiadorRow = {
  id: string;
  assessor_id: string;
  profile_id: string | null;
  nome: string;
  email: string | null;
};

async function assertCanManageApoiador(
  supabaseAdmin: ReturnType<typeof createClient>,
  callerId: string,
  apoiador: ApoiadorRow
): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const { data: caller, error: ce } = await supabaseAdmin.from('profiles').select('role').eq('id', callerId).single();
  if (ce || !caller) return { ok: false, status: 403, error: 'Perfil não encontrado' };

  const role = (caller as { role: string }).role;
  const assessorIdOfApoiador = apoiador.assessor_id;

  if (role === 'candidato') {
    const { data: inv } = await supabaseAdmin.from('profiles').select('id').eq('invited_by', callerId);
    const ids = [callerId, ...((inv ?? []) as { id: string }[]).map((x) => x.id)];
    const { data: row } = await supabaseAdmin
      .from('assessores')
      .select('id')
      .eq('id', assessorIdOfApoiador)
      .in('profile_id', ids)
      .maybeSingle();
    if (!row) return { ok: false, status: 403, error: 'Este apoiador não pertence à sua campanha' };
    return { ok: true };
  }

  if (role === 'assessor') {
    const { data: a } = await supabaseAdmin.from('assessores').select('id').eq('profile_id', callerId).maybeSingle();
    if (!a || (a as { id: string }).id !== assessorIdOfApoiador) {
      return { ok: false, status: 403, error: 'Apenas o assessor responsável pode convidar este apoiador' };
    }
    return { ok: true };
  }

  return { ok: false, status: 403, error: 'Apenas candidato ou assessor podem enviar convite ao apoiador' };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Método não permitido' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Não autorizado. Faça login novamente.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const token = authHeader.replace('Bearer ', '');
    const supabaseAnon = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    let callerId: string | null = null;
    const { data: claimsData, error: claimsError } = await supabaseAnon.auth.getClaims(token);
    if (!claimsError && claimsData?.claims?.sub) {
      callerId = claimsData.claims.sub as string;
    }
    if (!callerId) {
      const { data: { user } } = await supabaseAnon.auth.getUser(token);
      callerId = user?.id ?? null;
    }
    if (!callerId) {
      return new Response(JSON.stringify({ error: 'Sessão inválida ou expirada.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const body = await req.json();
    const apoiadorId = (body?.apoiador_id ?? '').toString().trim();
    if (!apoiadorId) {
      return new Response(JSON.stringify({ error: 'apoiador_id é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: apoiadorRaw, error: apoiadorError } = await supabaseAdmin
      .from('apoiadores')
      .select('id, assessor_id, profile_id, nome, email')
      .eq('id', apoiadorId)
      .single();

    if (apoiadorError || !apoiadorRaw) {
      return new Response(JSON.stringify({ error: 'Apoiador não encontrado' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const apoiador = apoiadorRaw as ApoiadorRow;
    const gate = await assertCanManageApoiador(supabaseAdmin, callerId, apoiador);
    if (!gate.ok) {
      return new Response(JSON.stringify({ error: gate.error }), {
        status: gate.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (apoiador.profile_id) {
      return new Response(
        JSON.stringify({
          error: 'Este apoiador já está vinculado a uma conta. Ele deve usar o e-mail cadastrado para entrar no app.',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const email = (apoiador.email ?? '').trim().toLowerCase();
    const nome = (apoiador.nome ?? '').trim();
    if (!email || !nome) {
      return new Response(
        JSON.stringify({ error: 'Cadastre nome e e-mail do apoiador antes de enviar o convite.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const rawRedirect = (body?.redirect_to && String(body.redirect_to).trim()) || '';
    const isLocalhost = rawRedirect.includes('localhost') || rawRedirect.includes('127.0.0.1');
    const redirectTo = !isLocalhost && rawRedirect ? rawRedirect : (Deno.env.get('REDIRECT_URL') || undefined);

    const { data: invited, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: nome, role: 'apoiador' },
      redirectTo,
    });

    if (inviteError) {
      const msg = inviteError.message || String(inviteError);
      if (msg.includes('already been registered') || msg.includes('already exists')) {
        return new Response(
          JSON.stringify({
            error:
              'Este e-mail já tem cadastro. Se for o apoiador, peça para entrar com esse e-mail; ou vincule manualmente no painel Supabase (auth.users → profiles).',
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      return new Response(JSON.stringify({ error: 'Falha ao enviar convite: ' + msg }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const newUserId = invited?.user?.id;
    if (!newUserId) {
      return new Response(JSON.stringify({ error: 'Convite enviado mas não foi possível obter o usuário' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: profileUpsertError } = await supabaseAdmin.from('profiles').upsert(
      {
        id: newUserId,
        full_name: nome,
        email,
        role: 'apoiador',
        invited_by: callerId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'id' }
    );
    if (profileUpsertError) {
      return new Response(JSON.stringify({ error: 'Falha ao atualizar perfil: ' + profileUpsertError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: linkApoiadorError } = await supabaseAdmin
      .from('apoiadores')
      .update({ profile_id: newUserId, updated_at: new Date().toISOString() })
      .eq('id', apoiadorId);

    if (linkApoiadorError) {
      return new Response(JSON.stringify({ error: 'Convite ok, mas falha ao vincular apoiador: ' + linkApoiadorError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let linkCopia: string | null = null;
    try {
      const { data: linkData, error: linkErr } = await supabaseAdmin.auth.admin.generateLink({
        type: 'invite',
        email,
        options: redirectTo ? { redirectTo } : {},
      });
      if (!linkErr && linkData?.properties && typeof (linkData.properties as { action_link?: string }).action_link === 'string') {
        linkCopia = (linkData.properties as { action_link: string }).action_link;
      }
    } catch {
      // ignora
    }

    return new Response(
      JSON.stringify({
        ok: true,
        message:
          'Convite enviado. O apoiador receberá um e-mail para criar a senha e poderá cadastrar votantes no mapa.',
        link_copia: linkCopia,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
