// Edge Function: Reenviar convite por e-mail para um assessor já cadastrado.
// Apenas candidato pode chamar. Tenta enviar novamente o convite Supabase Auth.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
      return new Response(JSON.stringify({ error: 'Sessão inválida ou expirada. Faça logout e login novamente.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: profileCaller } = await supabaseAdmin
      .from('profiles')
      .select('id, role')
      .eq('id', callerId)
      .single();

    if (!profileCaller || (profileCaller as { role: string }).role !== 'candidato') {
      return new Response(JSON.stringify({ error: 'Apenas o candidato pode reenviar convites' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const assessorId = (body?.assessor_id ?? '').trim();
    if (!assessorId) {
      return new Response(JSON.stringify({ error: 'assessor_id é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: assessor, error: assessorError } = await supabaseAdmin
      .from('assessores')
      .select('id, profile_id, nome, email')
      .eq('id', assessorId)
      .single();

    if (assessorError || !assessor) {
      return new Response(JSON.stringify({ error: 'Assessor não encontrado' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const email = ((assessor as { email: string | null }).email ?? '').trim().toLowerCase();
    const nome = ((assessor as { nome: string }).nome ?? '').trim();
    if (!email) {
      return new Response(JSON.stringify({ error: 'Assessor sem e-mail cadastrado' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const rawRedirect = (body?.redirect_to && String(body.redirect_to).trim()) || '';
    const isLocalhost = rawRedirect.includes('localhost') || rawRedirect.includes('127.0.0.1');
    const redirectTo = !isLocalhost && rawRedirect ? rawRedirect : (Deno.env.get('REDIRECT_URL') || undefined);
    const { error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: nome },
      redirectTo,
    });

    if (inviteError) {
      const msg = inviteError.message || String(inviteError);
      if (msg.includes('already been registered') || msg.includes('already exists') || msg.includes('already registered')) {
        return new Response(
          JSON.stringify({
            error: 'Este e-mail já completou o cadastro. Peça ao assessor para usar "Esqueci minha senha" na tela de login se precisar redefinir o acesso.',
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
