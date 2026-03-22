import 'dart:convert';

/// Decodifica o payload (2.º segmento) de um JWT sem validar assinatura.
Map<String, dynamic>? decodeJwtPayload(String jwt) {
  final parts = jwt.split('.');
  if (parts.length < 2) return null;
  var s = parts[1].replaceAll('-', '+').replaceAll('_', '/');
  switch (s.length % 4) {
    case 2:
      s += '==';
      break;
    case 3:
      s += '=';
      break;
    case 1:
      return null;
  }
  try {
    final obj = json.decode(utf8.decode(base64.decode(s)));
    if (obj is Map<String, dynamic>) return obj;
    return null;
  } catch (_) {
    return null;
  }
}

/// Sessão criada pelo link «esqueci minha senha» (fluxo PKCE ou implícito).
/// Ver: https://supabase.com/docs/guides/auth/jwt-fields — `amr` pode incluir `method: recovery`.
bool accessTokenIndicatesPasswordRecovery(String accessToken) {
  final payload = decodeJwtPayload(accessToken);
  if (payload == null) return false;
  final amr = payload['amr'];
  if (amr is! List) return false;
  for (final item in amr) {
    if (item is Map && item['method'] == 'recovery') return true;
    if (item == 'recovery') return true;
  }
  return false;
}
