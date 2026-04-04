// Reenviar convite por e-mail para apoiador já cadastrado (sem conta ativa ou pendente).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { assertCanManageApoiador, type ApoiadorRow } from '../_shared/apoiador-gate.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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
      return new Response(JSON.stringify({ error: 'Não autorizado.' }), {
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
    try {
      const { data: claimsData, error: claimsError } = await supabaseAnon.auth.getClaims(token);
      if (!claimsError && claimsData?.claims?.sub) {
        callerId = claimsData.claims.sub as string;
      }
    } catch {
      // segue para getUser
    }
    if (!callerId) {
      const { data: { user } } = await supabaseAnon.auth.getUser(token);
      callerId = user?.id ?? null;
    }
    if (!callerId) {
      return new Response(JSON.stringify({ error: 'Sessão inválida.' }), {
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
    const gate = await assertCanManageApoiador(supabaseAdmin, callerId, apoiador, {
      strictAssessorMessage: 'Apenas o assessor responsável pode reenviar o convite',
      forbiddenRoleMessage: 'Apenas candidato ou assessor podem reenviar convite',
    });
    if (!gate.ok) {
      return new Response(JSON.stringify({ error: gate.error }), {
        status: gate.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const email = (apoiador.email ?? '').trim().toLowerCase();
    const nome = (apoiador.nome ?? '').trim();
    if (!email) {
      return new Response(JSON.stringify({ error: 'Apoiador sem e-mail cadastrado' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const rawRedirect = (body?.redirect_to && String(body.redirect_to).trim()) || '';
    const isLocalhost = rawRedirect.includes('localhost') || rawRedirect.includes('127.0.0.1');
    const redirectTo = !isLocalhost && rawRedirect ? rawRedirect : (Deno.env.get('REDIRECT_URL') || undefined);

    const { error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: nome, role: 'apoiador' },
      redirectTo,
    });

    if (inviteError) {
      const msg = inviteError.message || String(inviteError);
      if (msg.includes('already been registered') || msg.includes('already exists') || msg.includes('already registered')) {
        return new Response(
          JSON.stringify({
            error:
              'Este e-mail já completou o cadastro. O apoiador deve usar login ou redefinir senha.',
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      return new Response(JSON.stringify({ error: 'Falha ao reenviar convite: ' + msg }), {
        status: 400,
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
      JSON.stringify({ ok: true, message: 'Convite reenviado por e-mail.', link_copia: linkCopia }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
