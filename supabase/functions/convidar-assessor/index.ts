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

/** Localiza usuário Auth por e-mail (lista paginada; projetos pequenos/médios). */
async function findUserIdByEmail(
  supabaseAdmin: ReturnType<typeof createClient>,
  email: string,
): Promise<string | null> {
  const needle = email.toLowerCase().trim();
  let page = 1;
  const perPage = 1000;
  for (;;) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    const u = data.users.find((x) => (x.email ?? '').toLowerCase() === needle);
    if (u) return u.id;
    if (data.users.length < perPage) return null;
    page++;
  }
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
    const grauRaw = Number(body?.grau_acesso);
    const grauAcesso = grauRaw === 1 ? 1 : 2;

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
        // E-mail já no Auth: vincula à campanha (invited_by + assessores). Sem invited_by o candidato não vê a linha (RLS).
        let existingId: string;
        try {
          const found = await findUserIdByEmail(supabaseAdmin, email);
          if (!found) {
            return new Response(
              JSON.stringify({
                error:
                  'Este e-mail já está cadastrado, mas não foi possível localizar o usuário. Tente de novo ou ajuste invited_by no SQL (profiles).',
              }),
              { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            );
          }
          existingId = found;
        } catch (e) {
          return new Response(JSON.stringify({ error: 'Erro ao buscar usuário existente: ' + String(e) }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (existingId === callerId) {
          return new Response(JSON.stringify({ error: 'Use outro e-mail — este é o seu próprio cadastro de candidato.' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        const { data: existingProfile, error: profFetchErr } = await supabaseAdmin
          .from('profiles')
          .select('role')
          .eq('id', existingId)
          .maybeSingle();
        if (profFetchErr) {
          return new Response(JSON.stringify({ error: 'Falha ao ler perfil: ' + profFetchErr.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        const role = (existingProfile?.role as string | undefined) ?? 'votante';
        if (role === 'candidato') {
          return new Response(JSON.stringify({ error: 'Este e-mail pertence a outro candidato; não pode ser assessor.' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        if (role === 'apoiador') {
          return new Response(
            JSON.stringify({
              error:
                'Este e-mail já está cadastrado como apoiador. Remova ou altere o cadastro de apoiador antes de vincular como assessor.',
            }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
          );
        }
        const { error: profileUpsertError2 } = await supabaseAdmin.from('profiles').upsert(
          {
            id: existingId,
            full_name: nome,
            email,
            role: 'assessor',
            invited_by: callerId,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'id' },
        );
        if (profileUpsertError2) {
          return new Response(JSON.stringify({ error: 'Falha ao atualizar perfil: ' + profileUpsertError2.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        const { error: assessorUpsertErr } = await supabaseAdmin.from('assessores').upsert(
          {
            profile_id: existingId,
            nome,
            email: email || null,
            telefone: telefone || null,
            municipio_id: municipioId || null,
            ativo: true,
            grau_acesso: grauAcesso,
          },
          { onConflict: 'profile_id' },
        );
        if (assessorUpsertErr) {
          return new Response(JSON.stringify({ error: 'Falha ao atualizar assessor: ' + assessorUpsertErr.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        return new Response(
          JSON.stringify({
            ok: true,
            existing_user: true,
            message:
              'Este e-mail já tinha cadastro. O vínculo com sua campanha foi atualizado — a assessora deve aparecer na lista após atualizar. Ela pode entrar com o e-mail e senha habituais.',
            link_copia: null,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
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
      grau_acesso: grauAcesso,
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
