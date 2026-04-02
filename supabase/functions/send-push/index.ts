// Supabase Edge Function: send-push
// Envia notificações Web Push para um ou mais usuários.
//
// Variáveis obrigatórias nos Supabase Secrets (Dashboard → Settings → Edge Functions):
//   VAPID_PRIVATE_KEY = mnHjP0KanTzCv-Lggkf_gpDZg8cBC9eTHo5phU_G8Q8
//   VAPID_PUBLIC_KEY  = BBDwFPKAU0cMMay9-WE1DadHmv_lFmGts80CaorhOl2zKW1HTSw4sQLpboixKQkerXexwYwJxSF4PcOK35Qa2DY
//   VAPID_SUBJECT     = mailto:eleicoes2026mt@gmail.com
//
// Como chamar via Supabase client (candidato/assessor):
//   supabase.functions.invoke('send-push', body: {
//     "profileIds": ["uuid-1", "uuid-2"],  // null = envia para todos
//     "title": "Nova mensagem",
//     "body": "Confira a atualização da campanha.",
//     "url": "/#/mensagens",
//     "tag": "mensagem"
//   })

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Helpers Web Push (VAPID) ──────────────────────────────────────────────────

function base64UrlToUint8Array(base64Url: string): Uint8Array {
  const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
  const rawData = atob(base64);
  return Uint8Array.from([...rawData].map((c) => c.charCodeAt(0)));
}

async function importVapidPrivateKey(rawB64Url: string): Promise<CryptoKey> {
  const raw = base64UrlToUint8Array(rawB64Url);
  return crypto.subtle.importKey(
    "raw",
    raw,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    ["deriveKey", "deriveBits"],
  );
}

async function buildVapidAuthHeader(
  endpoint: string,
  vapidPrivateKeyRaw: string,
  vapidPublicKeyRaw: string,
  subject: string,
): Promise<string> {
  const url = new URL(endpoint);
  const audience = `${url.protocol}//${url.host}`;
  const exp = Math.floor(Date.now() / 1000) + 12 * 3600;

  const header = { typ: "JWT", alg: "ES256" };
  const payload = { aud: audience, exp, sub: subject };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");

  const signingInput = `${enc(header)}.${enc(payload)}`;

  const keyData = base64UrlToUint8Array(vapidPrivateKeyRaw);
  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    key,
    new TextEncoder().encode(signingInput),
  );

  const sigB64 = btoa(
    String.fromCharCode(...new Uint8Array(signature)),
  ).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const jwt = `${signingInput}.${sigB64}`;
  return `vapid t=${jwt}, k=${vapidPublicKeyRaw}`;
}

async function sendWebPush(
  subscription: { endpoint: string; p256dh: string; auth_key: string },
  payload: string,
  vapidPrivateKey: string,
  vapidPublicKey: string,
  vapidSubject: string,
): Promise<{ ok: boolean; status: number }> {
  const authHeader = await buildVapidAuthHeader(
    subscription.endpoint,
    vapidPrivateKey,
    vapidPublicKey,
    vapidSubject,
  );

  const res = await fetch(subscription.endpoint, {
    method: "POST",
    headers: {
      Authorization: authHeader,
      "Content-Type": "application/octet-stream",
      TTL: "86400",
    },
    body: new TextEncoder().encode(payload),
  });

  return { ok: res.ok, status: res.status };
}

// ── Handler principal ─────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
  const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY") ??
    "BBDwFPKAU0cMMay9-WE1DadHmv_lFmGts80CaorhOl2zKW1HTSw4sQLpboixKQkerXexwYwJxSF4PcOK35Qa2DY";
  const vapidSubject = Deno.env.get("VAPID_SUBJECT") ?? "mailto:eleicoes2026mt@gmail.com";

  if (!vapidPrivateKey) {
    return jsonResponse({ error: "VAPID_PRIVATE_KEY não configurada nos Secrets." }, 500);
  }

  const body = await req.json().catch(() => ({}));
  const { profileIds, title, body: msgBody, url, tag, icon } = body as {
    profileIds?: string[];
    title: string;
    body: string;
    url?: string;
    tag?: string;
    icon?: string;
  };

  if (!title || !msgBody) {
    return jsonResponse({ error: "title e body são obrigatórios." }, 400);
  }

  // Usa service_role para ler todas as subscrições
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let query = supabase.from("push_subscriptions").select("*");
  if (profileIds && profileIds.length > 0) {
    query = query.in("profile_id", profileIds);
  }

  const { data: subs, error } = await query;
  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  const payload = JSON.stringify({
    title,
    body: msgBody,
    url: url ?? "/",
    tag: tag ?? "campanha-mt",
    icon: icon ?? "/icons/Icon-192.png",
  });

  const results = await Promise.allSettled(
    (subs ?? []).map((sub: {
      endpoint: string;
      p256dh: string;
      auth_key: string;
      id: string;
    }) =>
      sendWebPush(
        { endpoint: sub.endpoint, p256dh: sub.p256dh, auth_key: sub.auth_key },
        payload,
        vapidPrivateKey,
        vapidPublicKey,
        vapidSubject,
      ).then((r) => {
        // Subscrição expirada → remove do banco
        if (r.status === 410 || r.status === 404) {
          supabase.from("push_subscriptions").delete().eq("id", sub.id);
        }
        return r;
      })
    ),
  );

  const sent = results.filter((r) => r.status === "fulfilled" && (r as PromiseFulfilledResult<{ ok: boolean }>).value.ok).length;
  const failed = results.length - sent;

  return jsonResponse({ sent, failed, total: results.length });
});
