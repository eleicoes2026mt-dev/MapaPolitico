/** Colunas A–R da planilha «Gestão de Contatos». */

export const PLANILHA_HEADERS = [
  "Id",
  "Nome Completo *",
  "Nº WhatsApp *",
  "Município *",
  "Bairro / Região",
  "Lugar",
  "Faixa de Idade",
  "Tipo de Contato *",
  "Engajamento *",
  "Segmento de Atuação",
  "Pauta de Interesse",
  "Orientação Política",
  "Canal de Origem *",
  "Data de Entrada *",
  "Último Contato",
  "Grupos",
  "Observações",
  "Status *",
] as const;

export type TipoContatoPlanilha = "apoiador" | "votante" | "assessor";

export function planilhaRowId(tipo: TipoContatoPlanilha, uuid: string): string {
  return `${tipo}:${uuid}`;
}

function fmtData(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const dd = String(d.getDate()).padStart(2, "0");
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const yyyy = d.getFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

function faixaIdade(dataNascimento: string | null | undefined): string {
  if (!dataNascimento) return "";
  const d = new Date(dataNascimento);
  if (Number.isNaN(d.getTime())) return "";
  const hoje = new Date();
  let idade = hoje.getFullYear() - d.getFullYear();
  const m = hoje.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && hoje.getDate() < d.getDate())) idade--;
  if (idade < 18) return "Até 17 anos";
  if (idade <= 29) return "18–29 anos";
  if (idade <= 39) return "30–39 anos";
  if (idade <= 49) return "40–49 anos";
  if (idade <= 59) return "50–59 anos";
  return "60+ anos";
}

function joinObs(parts: (string | null | undefined)[]): string {
  return parts
    .map((p) => p?.trim())
    .filter((p) => p && p.length > 0)
    .join(" · ");
}

function origemLugarNome(r: Row): string {
  const ol = r.origem_lugar ?? r.apoiador_origem_lugares;
  if (ol && typeof ol === "object" && ol.nome) {
    return String(ol.nome).trim();
  }
  return (r.origem_lugar_nome as string)?.trim() ?? "";
}

function statusAtivo(ativo: boolean | null | undefined, excluidoEm?: string | null): string {
  if (excluidoEm) return "Excluído";
  if (ativo === false) return "Inativo";
  return "Ativo";
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;

export function mapApoiadorToPlanilhaRow(r: Row): string[] {
  const mun = r.municipios?.nome ?? r.cidade_nome ?? "";
  const obs = joinObs([
    r.email ? `E-mail: ${r.email}` : null,
    r.link_instagram ? `Instagram: ${r.link_instagram}` : null,
    r.logradouro
      ? `End.: ${[r.logradouro, r.numero, r.complemento].filter(Boolean).join(", ")}`
      : null,
    r.estimativa_votos != null ? `Est. votos: ${r.estimativa_votos}` : null,
  ]);

  return [
    planilhaRowId("apoiador", r.id as string),
    (r.nome as string) ?? "",
    (r.telefone as string) ?? (r.contato_responsavel as string) ?? "",
    mun,
    (r.complemento as string) ?? "",
    origemLugarNome(r),
    faixaIdade(r.data_nascimento as string),
    "Apoiador",
    (r.perfil as string)?.trim() || (r.ativo ? "Engajado" : "Baixo engajamento"),
    (r.perfil as string) ?? "",
    "",
    "",
    "App CampanhaMT",
    fmtData(r.created_at as string),
    fmtData(r.updated_at as string),
    r.tipo === "PJ" ? "PJ / Empresarial" : "PF",
    obs,
    statusAtivo(r.ativo as boolean, r.excluido_em as string),
  ];
}

export function mapVotanteToPlanilhaRow(r: Row): string[] {
  const mun = r.municipios?.nome ?? r.cidade_nome ?? "";
  const viaQr = r.cadastro_via_qr === true;
  const tipoContato = viaQr ? "Amigos do Gilberto" : "Votante";
  const canal = viaQr
    ? "Link Amigos do Gilberto"
    : r.cadastrado_pelo_candidato
    ? "Cadastro candidato"
    : "App CampanhaMT";

  const engajamento = r.abrangencia === "Familiar"
    ? `Familiar (${r.qtd_votos_familia ?? 1} votos)`
    : "Individual";

  const obs = joinObs([
    r.email ? `E-mail: ${r.email}` : null,
    r.link_instagram ? `Instagram: ${r.link_instagram}` : null,
    r.convite_por_nome ? `Convite por: ${r.convite_por_nome}` : null,
    r.logradouro
      ? `End.: ${[r.logradouro, r.numero, r.complemento].filter(Boolean).join(", ")}`
      : null,
  ]);

  return [
    planilhaRowId("votante", r.id as string),
    (r.nome as string) ?? "",
    (r.telefone as string) ?? "",
    mun,
    (r.complemento as string) ?? "",
    "",
    "",
    tipoContato,
    engajamento,
    "",
    "",
    "",
    canal,
    fmtData(r.created_at as string),
    fmtData(r.updated_at as string),
    viaQr ? "Rede Amigos" : "Rede campanha",
    obs,
    "Ativo",
  ];
}

export function mapAssessorToPlanilhaRow(r: Row): string[] {
  const mun = r.municipios?.nome ?? "";
  const grau = (r.grau_acesso as number) === 1 ? "Grau 1 — gestão completa" : "Grau 2 — padrão";
  const obs = joinObs([
    r.email ? `E-mail: ${r.email}` : null,
    r.link_instagram ? `Instagram: ${r.link_instagram}` : null,
    r.logradouro
      ? `End.: ${[r.logradouro, r.numero, r.complemento].filter(Boolean).join(", ")}`
      : null,
  ]);

  return [
    planilhaRowId("assessor", r.id as string),
    (r.nome as string) ?? "",
    (r.telefone as string) ?? "",
    mun,
    (r.complemento as string) ?? "",
    "",
    "",
    "Assessor",
    grau,
    "Equipe técnica",
    "",
    "",
    "Convite App CampanhaMT",
    fmtData(r.created_at as string),
    fmtData(r.updated_at as string),
    `Assessor grau ${r.grau_acesso ?? 2}`,
    obs,
    statusAtivo(r.ativo as boolean),
  ];
}

export function mapRecordToPlanilhaRow(
  tipo: TipoContatoPlanilha,
  r: Row,
): string[] {
  switch (tipo) {
    case "apoiador":
      return mapApoiadorToPlanilhaRow(r);
    case "votante":
      return mapVotanteToPlanilhaRow(r);
    case "assessor":
      return mapAssessorToPlanilhaRow(r);
  }
}
