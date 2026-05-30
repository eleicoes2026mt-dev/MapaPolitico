/**
 * Sincroniza apoiadores, votantes e assessores → Google Sheets.
 *
 * Secrets (Supabase Dashboard → Edge Functions → Secrets):
 *   GOOGLE_SHEETS_SPREADSHEET_ID
 *   GOOGLE_SHEETS_SHEET_NAME          (ex.: Página1)
 *   GOOGLE_SERVICE_ACCOUNT_EMAIL
 *   GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY (PEM; \\n para quebras de linha)
 *   PLANILHA_SYNC_SECRET              (mesmo valor em planilha_sync_config)
 *
 * Deploy:
 *   supabase functions deploy sync-contatos-planilha --no-verify-jwt
 *
 * Corpo POST:
 *   { "modo": "completo" }                           — repõe todas as linhas (gestor)
 *   { "modo": "registro", "tipo": "apoiador", "id": "uuid" }  — webhook/trigger
 *
 * Auth:
 *   - Header X-Planilha-Sync-Secret (triggers automáticos)
 *   - OU Bearer JWT de candidato / assessor grau 1 (sync manual completo)
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  getGoogleSheetsAccessToken,
  GoogleSheetsClient,
} from "../_shared/google-sheets-client.ts";
import {
  mapApoiadorToPlanilhaRow,
  mapAssessorToPlanilhaRow,
  mapRecordToPlanilhaRow,
  mapVotanteToPlanilhaRow,
  type TipoContatoPlanilha,
} from "../_shared/planilha-contatos-map.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, x-client-info, apikey, x-supabase-api-version, x-planilha-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const APOIADOR_SELECT =
  "*, municipios(nome), apoiador_origem_lugares(nome)";
const VOTANTE_SELECT = "*, municipios(nome)";
const ASSESSOR_SELECT = "*, municipios(nome)";

function sheetsConfig() {
  const spreadsheetId = Deno.env.get("GOOGLE_SHEETS_SPREADSHEET_ID")?.trim();
  const sheetName = Deno.env.get("GOOGLE_SHEETS_SHEET_NAME")?.trim() || "Página1";
  const email = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL")?.trim();
  const privateKey = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY")?.trim();
  if (!spreadsheetId || !email || !privateKey) {
    throw new Error(
      "Configure GOOGLE_SHEETS_SPREADSHEET_ID, GOOGLE_SERVICE_ACCOUNT_EMAIL e GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY nos secrets.",
    );
  }
  return { spreadsheetId, sheetName, email, privateKey };
}

async function sheetsClient(): Promise<{ client: GoogleSheetsClient; sheetName: string }> {
  const cfg = sheetsConfig();
  const token = await getGoogleSheetsAccessToken(cfg.email, cfg.privateKey);
  return {
    client: new GoogleSheetsClient(cfg.spreadsheetId, token),
    sheetName: cfg.sheetName,
  };
}

async function isGestorCampanha(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
): Promise<boolean> {
  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  if (profile?.role === "candidato") return true;
  if (profile?.role !== "assessor") return false;
  const { data: assessor } = await supabaseAdmin
    .from("assessores")
    .select("grau_acesso, ativo")
    .eq("profile_id", userId)
    .maybeSingle();
  return assessor?.ativo !== false && assessor?.grau_acesso === 1;
}

async function fetchApoiadores(admin: ReturnType<typeof createClient>) {
  const { data, error } = await admin
    .from("apoiadores")
    .select(APOIADOR_SELECT)
    .is("excluido_em", null)
    .order("nome");
  if (error) throw error;
  return data ?? [];
}

async function fetchVotantes(admin: ReturnType<typeof createClient>) {
  const { data, error } = await admin
    .from("votantes")
    .select(VOTANTE_SELECT)
    .order("nome");
  if (error) throw error;
  return data ?? [];
}

async function fetchAssessores(admin: ReturnType<typeof createClient>) {
  const { data, error } = await admin
    .from("assessores")
    .select(`${ASSESSOR_SELECT}, profiles(role)`)
    .order("nome");
  if (error) throw error;
  return (data ?? []).filter((a) => {
    const pr = a.profiles as { role?: string } | null;
    return pr?.role !== "candidato";
  });
}

async function fetchOne(
  admin: ReturnType<typeof createClient>,
  tipo: TipoContatoPlanilha,
  id: string,
) {
  if (tipo === "apoiador") {
    const { data, error } = await admin
      .from("apoiadores")
      .select(APOIADOR_SELECT)
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    return data;
  }
  if (tipo === "votante") {
    const { data, error } = await admin
      .from("votantes")
      .select(VOTANTE_SELECT)
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    return data;
  }
  const { data, error } = await admin
    .from("assessores")
    .select(ASSESSOR_SELECT)
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function syncCompleto(admin: ReturnType<typeof createClient>) {
  const [apoiadores, votantes, assessores] = await Promise.all([
    fetchApoiadores(admin),
    fetchVotantes(admin),
    fetchAssessores(admin),
  ]);

  const rows: string[][] = [];
  for (const a of apoiadores) rows.push(mapApoiadorToPlanilhaRow(a));
  for (const v of votantes) rows.push(mapVotanteToPlanilhaRow(v));
  for (const s of assessores) rows.push(mapAssessorToPlanilhaRow(s));

  rows.sort((a, b) => a[1].localeCompare(b[1], "pt-BR"));

  const { client, sheetName } = await sheetsClient();
  await client.replaceAllDataRows(sheetName, rows);

  return {
    ok: true,
    modo: "completo",
    total: rows.length,
    apoiadores: apoiadores.length,
    votantes: votantes.length,
    assessores: assessores.length,
  };
}

async function syncRegistro(
  admin: ReturnType<typeof createClient>,
  tipo: TipoContatoPlanilha,
  id: string,
) {
  const row = await fetchOne(admin, tipo, id);
  if (!row) {
    return { ok: true, modo: "registro", acao: "ignorado", motivo: "registro não encontrado" };
  }
  if (tipo === "apoiador" && row.excluido_em) {
    return { ok: true, modo: "registro", acao: "ignorado", motivo: "apoiador excluído" };
  }

  const values = mapRecordToPlanilhaRow(tipo, row);
  const { client, sheetName } = await sheetsClient();
  const acao = await client.upsertRow(sheetName, values[0], values);

  return { ok: true, modo: "registro", tipo, id, acao };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const syncSecret = Deno.env.get("PLANILHA_SYNC_SECRET")?.trim();
  const headerSecret = req.headers.get("x-planilha-sync-secret")?.trim();
  const isWebhook = !!syncSecret && headerSecret === syncSecret;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey);

  let callerGestor = false;
  if (!isWebhook) {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Não autorizado." }, 401);
    }
    const token = authHeader.replace("Bearer ", "");
    const anon = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await anon.auth.getUser(token);
    if (!user) return json({ error: "Sessão inválida." }, 401);
    callerGestor = await isGestorCampanha(admin, user.id);
    if (!callerGestor) {
      return json({ error: "Apenas candidato ou assessor grau 1 pode sincronizar." }, 403);
    }
  }

  const body = await req.json().catch(() => ({})) as {
    modo?: string;
    tipo?: string;
    id?: string;
  };

  const modo = body.modo ?? (body.tipo && body.id ? "registro" : "completo");

  try {
    if (modo === "registro") {
      const tipo = body.tipo as TipoContatoPlanilha;
      const id = body.id?.trim();
      if (!tipo || !id || !["apoiador", "votante", "assessor"].includes(tipo)) {
        return json({ error: "Informe tipo (apoiador|votante|assessor) e id." }, 400);
      }
      const result = await syncRegistro(admin, tipo, id);
      return json(result);
    }

    if (modo === "completo") {
      const result = await syncCompleto(admin);
      return json(result);
    }

    return json({ error: "modo inválido (use completo ou registro)." }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("sync-contatos-planilha:", msg);
    return json({ error: msg }, 500);
  }
});
