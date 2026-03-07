// Edge Function: alertas quando região atinge alta performance ou está crítica
// Pode ser chamada por cron ou por trigger no Supabase após atualização de metas/votantes

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

    const { data: metas } = await supabase.from('metas_regionais').select('*, polos_regioes(nome)');
    const { data: metaEstadual } = await supabase.from('meta_estadual').select('meta_votos').single();

    const alertas: string[] = [];

    for (const m of metas || []) {
      // Aqui você calcularia votos atuais por polo (votantes + apoiadores estimativa)
      // e compararia com m.meta_votos para % performance
      const votosAtuais = 0; // placeholder: buscar soma por polo
      const pct = m.meta_votos > 0 ? (votosAtuais / m.meta_votos) * 100 : 0;
      if (pct >= 110) alertas.push(`Alta performance: ${(m as any).polos_regioes?.nome ?? m.polo_id} (${pct.toFixed(0)}%)`);
      if (pct < 50 && votosAtuais > 0) alertas.push(`Atenção: ${(m as any).polos_regioes?.nome ?? m.polo_id} abaixo da meta (${pct.toFixed(0)}%)`);
    }

    return new Response(
      JSON.stringify({ ok: true, alertas }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
