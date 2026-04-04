// Edge Function: Candidato convida assessor por email.
// Cria o usuário (convite), atualiza profile (role assessor) e insere em assessores.
// Só pode ser chamado por usuário com role candidato.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { displayNameForProfile, inviteUserMetadataAssessor } from '../_shared/invite-metadata.ts';

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
    // getClaims valida o JWT (compatível com novos signing keys); fallback para getUser
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

    const { data: isCandidato, error: candidatoRpcErr } = await supabaseAdmin.rpc('edge_is_candidato_profile', {
      p_id: callerId,
    });
    if (candidatoRpcErr) {
      console.error('edge_is_candidato_profile', candidatoRpcErr);
      return new Response(
        JSON.stringify({
          error:
            'Falha ao validar candidato. Rode a migração edge_is_candidato_profile no SQL do Supabase e faça redeploy desta função.',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    if (!isCandidato) {
      return new Response(JSON.stringify({ error: 'Apenas o candidato pode convidar assessores' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const nome = (body?.nome ?? '').trim();
    const email = (body?.email ?? '').trim().toLowerCase();
    if (!nome || !email) {
      return new Response(JSON.stringify({ error: 'Nome e e-mail são obrigatórios' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const telefone = (body?.telefone ?? '').trim() || null;
    const municipioId = body?.municipio_id ?? null;

    // redirectTo: nunca usar localhost; prioridade: body válido > env REDIRECT_URL
    const rawRedirect = (body?.redirect_to && String(body.redirect_to).trim()) || '';
    const isLocalhost = rawRedirect.includes('localhost') || rawRedirect.includes('127.0.0.1');
    const redirectTo = !isLocalhost && rawRedirect ? rawRedirect : (Deno.env.get('REDIRECT_URL') || undefined);
    const candidatoNome = await displayNameForProfile(supabaseAdmin, callerId);
    const inviteMeta = inviteUserMetadataAssessor({ convidadoNome: nome, candidatoNome });
    const { data: invited, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      data: inviteMeta,
      redirectTo,
    });

    if (inviteError) {
      const msg = inviteError.message || String(inviteError);
      if (msg.includes('already been registered') || msg.includes('already exists')) {
        return new Response(JSON.stringify({ error: 'Este e-mail já está cadastrado. Use outro ou peça à pessoa para fazer login.' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
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

    // Garantir que o profile existe (o trigger pode ainda não ter rodado) e já com role assessor
    const { error: profileUpsertError } = await supabaseAdmin.from('profiles').upsert(
      {
        id: newUserId,
        full_name: nome,
        email,
        role: 'assessor',
        invited_by: callerId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'id' }
    );
    if (profileUpsertError) {
      return new Response(JSON.stringify({ error: 'Falha ao criar/atualizar perfil: ' + profileUpsertError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: assessorError } = await supabaseAdmin.from('assessores').insert({
      profile_id: newUserId,
      nome,
      email: email || null,
      telefone: telefone || null,
      municipio_id: municipioId || null,
      ativo: true,
    });

    if (assessorError) {
      return new Response(JSON.stringify({ error: 'Perfil criado, mas falha ao criar assessor: ' + assessorError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Link copiável: se o e-mail do Supabase não chegar (SMTP/spam), o candidato envia pelo WhatsApp.
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
      // ignora: convite por e-mail já foi disparado
    }

    return new Response(
      JSON.stringify({
        ok: true,
        message: 'Convite enviado. O assessor receberá um e-mail para definir a senha e acessar o sistema.',
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
