// Supabase Edge Function: send-push
// Usa a biblioteca web-push (npm) para envio confiável com VAPID.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "https://esm.sh/web-push@3.6.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, x-client-info, apikey, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
  const VAPID_PUBLIC  = Deno.env.get("VAPID_PUBLIC_KEY")  ??
    "BBDwFPKAU0cMMay9-WE1DadHmv_lFmGts80CaorhOl2zKW1HTSw4sQLpboixKQkerXexwYwJxSF4PcOK35Qa2DY";
  const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ?? "mailto:eleicoes2026mt@gmail.com";

  if (!VAPID_PRIVATE) return json({ error: "VAPID_PRIVATE_KEY não configurada." }, 500);

  // Configura as chaves VAPID uma única vez
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

  const body = await req.json().catch(() => ({}));
  const { profileIds, title, body: msgBody, url, tag, icon } = body as {
    profileIds?: string[];
    title: string;
    body: string;
    url?: string;
    tag?: string;
    icon?: string;
  };

  if (!title || !msgBody) return json({ error: "title e body são obrigatórios." }, 400);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let query = supabase.from("push_subscriptions").select("*");
  if (profileIds?.length) query = query.in("profile_id", profileIds);

  const { data: subs, error } = await query;
  if (error) return json({ error: error.message }, 500);

  const payload = JSON.stringify({
    title,
    body: msgBody,
    url: url ?? "/",
    tag: tag ?? "campanha-mt",
    icon: icon ?? "/icons/Icon-192.png",
  });

  let sent = 0, failed = 0;

  for (const sub of subs ?? []) {
    try {
      await webpush.sendNotification(
        {
          endpoint: sub.endpoint,
          keys: { p256dh: sub.p256dh, auth: sub.auth_key },
        },
        payload,
        { TTL: 86400 },
      );
      sent++;
    } catch (err: unknown) {
      failed++;
      const status = (err as { statusCode?: number }).statusCode;
      // Subscriptions expiradas → remove do banco
      if (status === 410 || status === 404) {
        await supabase.from("push_subscriptions").delete().eq("id", sub.id);
      }
      console.error("Push failed for", sub.id, status, err);
    }
  }

  return json({ sent, failed, total: (subs ?? []).length });
});
