/** Cliente mínimo Google Sheets API v4 (service account JWT). */

const SHEETS_SCOPE = "https://www.googleapis.com/auth/spreadsheets";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const normalized = pem.includes("\\n")
    ? pem.replace(/\\n/g, "\n")
    : pem;
  return crypto.subtle.importKey(
    "pkcs8",
    pemToDer(normalized),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function signJwt(
  header: Record<string, string>,
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const encHeader = base64UrlEncode(JSON.stringify(header));
  const encPayload = base64UrlEncode(JSON.stringify(payload));
  const unsigned = `${encHeader}.${encPayload}`;
  const key = await importPrivateKey(privateKeyPem);
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64UrlEncode(new Uint8Array(sig))}`;
}

let cachedToken: { token: string; exp: number } | null = null;

export async function getGoogleSheetsAccessToken(
  serviceAccountEmail: string,
  privateKeyPem: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp > now + 60) {
    return cachedToken.token;
  }
  const jwt = await signJwt(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccountEmail,
      scope: SHEETS_SCOPE,
      aud: TOKEN_URL,
      iat: now,
      exp: now + 3600,
    },
    privateKeyPem,
  );
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Google OAuth falhou (${res.status}): ${t}`);
  }
  const data = await res.json() as { access_token: string; expires_in: number };
  cachedToken = { token: data.access_token, exp: now + data.expires_in };
  return data.access_token;
}

export class GoogleSheetsClient {
  constructor(
    private spreadsheetId: string,
    private accessToken: string,
  ) {}

  private async api(
    path: string,
    init?: RequestInit,
  ): Promise<Response> {
    const url = `https://sheets.googleapis.com/v4/spreadsheets/${this.spreadsheetId}${path}`;
    const res = await fetch(url, {
      ...init,
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
        ...(init?.headers ?? {}),
      },
    });
    return res;
  }

  /** Lê coluna A (Ids) a partir da linha 2. */
  async readIdColumn(sheetName: string): Promise<{ row: number; id: string }[]> {
    const range = encodeURIComponent(`${sheetName}!A2:A`);
    const res = await this.api(`/values/${range}`);
    if (!res.ok) {
      throw new Error(`Sheets read falhou (${res.status}): ${await res.text()}`);
    }
    const data = await res.json() as { values?: string[][] };
    const out: { row: number; id: string }[] = [];
    const rows = data.values ?? [];
    for (let i = 0; i < rows.length; i++) {
      const id = (rows[i]?.[0] ?? "").trim();
      if (id) out.push({ row: i + 2, id });
    }
    return out;
  }

  async upsertRow(
    sheetName: string,
    rowId: string,
    values: string[],
  ): Promise<"inserted" | "updated"> {
    const ids = await this.readIdColumn(sheetName);
    const found = ids.find((x) => x.id === rowId);
    const range = found
      ? `${sheetName}!A${found.row}:R${found.row}`
      : `${sheetName}!A:R`;

    if (found) {
      const res = await this.api(
        `/values/${encodeURIComponent(range)}?valueInputOption=USER_ENTERED`,
        {
          method: "PUT",
          body: JSON.stringify({ values: [values] }),
        },
      );
      if (!res.ok) {
        throw new Error(`Sheets update falhou (${res.status}): ${await res.text()}`);
      }
      return "updated";
    }

    const res = await this.api(
      `/values/${encodeURIComponent(range)}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`,
      {
        method: "POST",
        body: JSON.stringify({ values: [values] }),
      },
    );
    if (!res.ok) {
      throw new Error(`Sheets append falhou (${res.status}): ${await res.text()}`);
    }
    return "inserted";
  }

  /** Reescreve todas as linhas de dados (mantém cabeçalho na linha 1). */
  async replaceAllDataRows(
    sheetName: string,
    rows: string[][],
  ): Promise<void> {
    const clearRange = encodeURIComponent(`${sheetName}!A2:R`);
    const clearRes = await this.api(`/values/${clearRange}:clear`, { method: "POST" });
    if (!clearRes.ok) {
      throw new Error(`Sheets clear falhou (${clearRes.status}): ${await clearRes.text()}`);
    }
    if (rows.length === 0) return;

    const writeRange = encodeURIComponent(`${sheetName}!A2`);
    const writeRes = await this.api(
      `/values/${writeRange}?valueInputOption=USER_ENTERED`,
      {
        method: "PUT",
        body: JSON.stringify({ values: rows }),
      },
    );
    if (!writeRes.ok) {
      throw new Error(`Sheets write falhou (${writeRes.status}): ${await writeRes.text()}`);
    }
  }
}
