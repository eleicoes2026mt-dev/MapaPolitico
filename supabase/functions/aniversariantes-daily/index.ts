// Edge Function: envio diário de parabéns (aniversariantes do dia)
// Agendar com pg_cron ou Supabase Cron: 0 8 * * * (todo dia às 8h)

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

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const today = new Date();
    const month = today.getMonth() + 1;
    const day = today.getDate();

    const { data: todos, error: err } = await supabase.from('aniversariantes').select('id, nome, telefone, email, data_nascimento');
    if (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const aniversariantes = (todos || []).filter((a: any) => {
      const d = a.data_nascimento ? new Date(a.data_nascimento) : null;
      return d && d.getMonth() + 1 === month && d.getDate() === day;
    });

    const results: { nome: string; enviado_whatsapp?: boolean; enviado_email?: boolean }[] = [];

    for (const a of aniversariantes) {
      // Integração WhatsApp Business API (exemplo: Twilio, Evolution API, etc.)
      // await enviarWhatsApp(a.telefone, `Feliz aniversário, ${a.nome}! ...`);
      // Integração e-mail (Resend, SendGrid, etc.)
      // await enviarEmail(a.email, 'Parabéns!', `...`);
      results.push({ nome: a.nome });
    }

    return new Response(
      JSON.stringify({ ok: true, total: aniversariantes.length, resultados: results }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
