/**
 * CampanhaMT — sync Supabase → Google Sheets (SEM chave JSON da conta de serviço).
 *
 * 1. Planilha → Extensões → Apps Script → colar este arquivo.
 * 2. Projeto → Configurações do projeto → Propriedades do script:
 *      SUPABASE_URL           = https://SEU_REF.supabase.co
 *      SUPABASE_ANON_KEY      = chave anon/public do Supabase (Settings → API)
 *      PLANILHA_EXPORT_SECRET = mesma senha em planilha_sync_config.webhook_secret
 *      SPREADSHEET_ID         = ID da planilha (URL: .../d/ESTE_ID/edit) — obrigatório p/ sync automática
 *      SHEET_NAME             = Página1  (opcional; nome exato da aba)
 * 3. Executar once: instalarMenuPlanilha (autorizar)
 * 4. Implantar → Nova implantação → App da Web:
 *      Executar como: Eu
 *      Quem tem acesso: Qualquer pessoa
 *    Copie a URL → planilha_sync_config.apps_script_webapp_url
 * 5. No Supabase SQL Editor: sync_enabled = true + webhook_secret + apps_script_webapp_url
 */

var HEADERS = [
  'Id', 'Nome Completo *', 'Nº WhatsApp *', 'Município *', 'Bairro / Região', 'Lugar',
  'Faixa de Idade', 'Tipo de Contato *', 'Engajamento *', 'Segmento de Atuação',
  'Pauta de Interesse', 'Orientação Política', 'Canal de Origem *', 'Data de Entrada *',
  'Último Contato', 'Grupos', 'Observações', 'Status *'
];

function getCfg_() {
  var p = PropertiesService.getScriptProperties();
  var url = (p.getProperty('SUPABASE_URL') || '').replace(/\/$/, '');
  var secret = p.getProperty('PLANILHA_EXPORT_SECRET') || '';
  var anonKey = p.getProperty('SUPABASE_ANON_KEY') || '';
  var sheetName = p.getProperty('SHEET_NAME') || '';
  if (!url || !secret || !anonKey) {
    throw new Error('Configure SUPABASE_URL, SUPABASE_ANON_KEY e PLANILHA_EXPORT_SECRET nas propriedades do script.');
  }
  return { url: url, secret: secret, anonKey: anonKey, sheetName: sheetName };
}

function fmtData_(iso) {
  if (!iso) return '';
  var d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  var dd = ('0' + d.getDate()).slice(-2);
  var mm = ('0' + (d.getMonth() + 1)).slice(-2);
  return dd + '/' + mm + '/' + d.getFullYear();
}

/** Ex.: 65999506880 → (65) 9 9950-6880 */
function fmtTelefone_(raw) {
  if (!raw) return '';
  var digits = String(raw).replace(/\D/g, '');
  if (digits.indexOf('55') === 0 && digits.length >= 12) {
    digits = digits.substring(2);
  }
  if (digits.length === 11 && digits.charAt(2) === '9') {
    return '(' + digits.substring(0, 2) + ') ' + digits.charAt(2) + ' ' +
      digits.substring(3, 7) + '-' + digits.substring(7);
  }
  if (digits.length === 10) {
    return '(' + digits.substring(0, 2) + ') ' +
      digits.substring(2, 6) + '-' + digits.substring(6);
  }
  if (digits.length === 9 && digits.charAt(0) === '9') {
    return digits.charAt(0) + ' ' + digits.substring(1, 5) + '-' + digits.substring(5);
  }
  if (digits.length === 8) {
    return digits.substring(0, 4) + '-' + digits.substring(4);
  }
  return String(raw).trim();
}

function faixaIdade_(iso) {
  if (!iso) return '';
  var d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  var hoje = new Date();
  var idade = hoje.getFullYear() - d.getFullYear();
  if (hoje.getMonth() < d.getMonth() || (hoje.getMonth() === d.getMonth() && hoje.getDate() < d.getDate())) {
    idade--;
  }
  if (idade < 18) return 'Até 17 anos';
  if (idade <= 29) return '18–29 anos';
  if (idade <= 39) return '30–39 anos';
  if (idade <= 49) return '40–49 anos';
  if (idade <= 59) return '50–59 anos';
  return '60+ anos';
}

function joinObs_(parts) {
  return parts.filter(function (x) { return x && String(x).trim(); }).join(' · ');
}

function rowId_(tipo, id) {
  return tipo + ':' + id;
}

function mapRecord_(rec) {
  var tipo = rec.tipo;
  if (tipo === 'apoiador') {
    var obsA = joinObs_([
      rec.email ? 'E-mail: ' + rec.email : '',
      rec.link_instagram ? 'Instagram: ' + rec.link_instagram : '',
      rec.logradouro ? 'End.: ' + [rec.logradouro, rec.numero, rec.complemento_end].filter(Boolean).join(', ') : '',
      rec.estimativa_votos != null ? 'Est. votos: ' + rec.estimativa_votos : ''
    ]);
    var statusA = rec.excluido_em ? 'Excluído' : (rec.ativo === false ? 'Inativo' : 'Ativo');
    return [
      rowId_('apoiador', rec.id), rec.nome || '', fmtTelefone_(rec.telefone), rec.municipio || '',
      rec.bairro || '', rec.lugar || '', faixaIdade_(rec.data_nascimento),
      'Apoiador', (rec.perfil || '').trim() || (rec.ativo !== false ? 'Engajado' : 'Baixo engajamento'),
      rec.perfil || '', '', '', 'App CampanhaMT',
      fmtData_(rec.created_at), fmtData_(rec.updated_at),
      rec.tipo_pessoa === 'PJ' ? 'PJ / Empresarial' : 'PF', obsA, statusA
    ];
  }
  if (tipo === 'votante') {
    var viaQr = rec.cadastro_via_qr === true;
    var canal = viaQr ? 'Link Amigos do Gilberto' : (rec.cadastrado_pelo_candidato ? 'Cadastro candidato' : 'App CampanhaMT');
    var eng = rec.abrangencia === 'Familiar'
      ? 'Familiar (' + (rec.qtd_votos_familia || 1) + ' votos)' : 'Individual';
    var obsV = joinObs_([
      rec.email ? 'E-mail: ' + rec.email : '',
      rec.link_instagram ? 'Instagram: ' + rec.link_instagram : '',
      rec.convite_por_nome ? 'Convite por: ' + rec.convite_por_nome : '',
      rec.logradouro ? 'End.: ' + [rec.logradouro, rec.numero].filter(Boolean).join(', ') : ''
    ]);
    return [
      rowId_('votante', rec.id), rec.nome || '', fmtTelefone_(rec.telefone), rec.municipio || '',
      rec.bairro || '', '', '', viaQr ? 'Amigos do Gilberto' : 'Votante', eng,
      '', '', '', canal, fmtData_(rec.created_at), fmtData_(rec.updated_at),
      viaQr ? 'Rede Amigos' : 'Rede campanha', obsV, 'Ativo'
    ];
  }
  if (tipo === 'assessor') {
    var grau = rec.grau_acesso === 1 ? 'Grau 1 — gestão completa' : 'Grau 2 — padrão';
    var obsS = joinObs_([
      rec.email ? 'E-mail: ' + rec.email : '',
      rec.link_instagram ? 'Instagram: ' + rec.link_instagram : '',
      rec.logradouro ? 'End.: ' + [rec.logradouro, rec.numero].filter(Boolean).join(', ') : ''
    ]);
    var statusS = rec.ativo === false ? 'Inativo' : 'Ativo';
    return [
      rowId_('assessor', rec.id), rec.nome || '', fmtTelefone_(rec.telefone), rec.municipio || '',
      rec.bairro || '', '', '', 'Assessor', grau, 'Equipe técnica', '', '',
      'Convite App CampanhaMT', fmtData_(rec.created_at), fmtData_(rec.updated_at),
      'Assessor grau ' + (rec.grau_acesso || 2), obsS, statusS
    ];
  }
  return null;
}

function rpc_(cfg, fn, payload) {
  var res = UrlFetchApp.fetch(cfg.url + '/rest/v1/rpc/' + fn, {
    method: 'post',
    contentType: 'application/json',
    headers: {
      apikey: cfg.anonKey,
      Authorization: 'Bearer ' + cfg.anonKey
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });
  var code = res.getResponseCode();
  var text = res.getContentText();
  if (code >= 300) {
    throw new Error('RPC ' + fn + ' falhou (' + code + '): ' + text);
  }
  return JSON.parse(text);
}

function getSpreadsheet_() {
  var p = PropertiesService.getScriptProperties();
  var id = (p.getProperty('SPREADSHEET_ID') || '').trim();
  if (id) {
    return SpreadsheetApp.openById(id);
  }
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  if (ss) return ss;
  throw new Error(
    'Configure SPREADSHEET_ID nas propriedades do script (ID na URL da planilha). ' +
    'Abra a planilha e execute salvarIdPlanilha_() uma vez.'
  );
}

function salvarIdPlanilha_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) {
    throw new Error('Abra a planilha antes de salvar o ID.');
  }
  PropertiesService.getScriptProperties().setProperty('SPREADSHEET_ID', ss.getId());
  return ss.getId();
}

function getSheet_() {
  var cfg = getCfg_();
  var ss = getSpreadsheet_();
  if (cfg.sheetName) {
    var named = ss.getSheetByName(cfg.sheetName);
    if (!named) {
      throw new Error('Aba não encontrada: ' + cfg.sheetName);
    }
    return named;
  }
  return ss.getSheets()[0];
}

function ensureHeaders_(sheet) {
  var first = sheet.getRange(1, 1, 1, HEADERS.length).getValues()[0];
  if (first.join('') === '') {
    sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
  }
}

function upsertRow_(sheet, rowId, rowValues) {
  var lastRow = Math.max(sheet.getLastRow(), 1);
  var ids = lastRow >= 2
    ? sheet.getRange(2, 1, lastRow, 1).getValues().flat()
    : [];
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i]).trim() === rowId) {
      sheet.getRange(i + 2, 1, 1, rowValues.length).setValues([rowValues]);
      return 'updated';
    }
  }
  sheet.getRange(lastRow + 1, 1, 1, rowValues.length).setValues([rowValues]);
  return 'inserted';
}

function syncCompleto_() {
  var cfg = getCfg_();
  var sheet = getSheet_();
  ensureHeaders_(sheet);

  var data = rpc_(cfg, 'planilha_export_contatos', { p_secret: cfg.secret });
  var records = data.records || [];
  var rows = records.map(mapRecord_).filter(Boolean);
  rows.sort(function (a, b) { return String(a[1]).localeCompare(String(b[1]), 'pt-BR'); });

  if (sheet.getLastRow() > 1) {
    sheet.getRange(2, 1, sheet.getLastRow(), HEADERS.length).clearContent();
  }
  if (rows.length > 0) {
    sheet.getRange(2, 1, rows.length, HEADERS.length).setValues(rows);
  }
  return { ok: true, total: rows.length };
}

function syncRegistro_(tipo, id) {
  var cfg = getCfg_();
  var sheet = getSheet_();
  ensureHeaders_(sheet);
  var data = rpc_(cfg, 'planilha_export_contato', {
    p_secret: cfg.secret,
    p_tipo: tipo,
    p_id: id
  });
  if (!data.record) return { ok: true, acao: 'ignorado' };
  var row = mapRecord_(data.record);
  if (!row) return { ok: true, acao: 'ignorado' };
  var acao = upsertRow_(sheet, row[0], row);
  return { ok: true, acao: acao, id: row[0] };
}

function sincronizarPlanilhaCompleta() {
  var r = syncCompleto_();
  SpreadsheetApp.getActiveSpreadsheet().toast('Sync concluída: ' + r.total + ' linhas.', 'CampanhaMT', 5);
}

function onOpen() {
  instalarMenuPlanilha();
}

function instalarMenuPlanilha() {
  try {
    salvarIdPlanilha_();
  } catch (e) { /* planilha fechada */ }
  SpreadsheetApp.getUi()
    .createMenu('Gestão de Contatos')
    .addItem('Sincronizar agora (Supabase)', 'sincronizarPlanilhaCompleta')
    .addItem('Salvar ID da planilha (sync automática)', 'menuSalvarIdPlanilha')
    .addToUi();
}

function menuSalvarIdPlanilha() {
  var id = salvarIdPlanilha_();
  SpreadsheetApp.getActiveSpreadsheet().toast('ID salvo: ' + id, 'CampanhaMT', 5);
}

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({
    ok: true,
    service: 'CampanhaMT planilha sync',
    hint: 'Use POST com { secret, modo: "completo" } ou menu na planilha.'
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    if (!body.secret || body.secret !== getCfg_().secret) {
      return ContentService.createTextOutput(JSON.stringify({ error: 'secret inválido' }))
        .setMimeType(ContentService.MimeType.JSON);
    }
    if (body.modo === 'registro' && body.tipo && body.id) {
      var r = syncRegistro_(body.tipo, body.id);
      return ContentService.createTextOutput(JSON.stringify(r)).setMimeType(ContentService.MimeType.JSON);
    }
    if (body.modo === 'completo') {
      var c = syncCompleto_();
      return ContentService.createTextOutput(JSON.stringify(c)).setMimeType(ContentService.MimeType.JSON);
    }
    return ContentService.createTextOutput(JSON.stringify({ error: 'modo inválido' }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ error: String(err.message || err) }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
