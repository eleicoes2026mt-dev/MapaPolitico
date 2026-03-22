// Callback de auth só na build web; dart:html continua suportado no Flutter web.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// URL completa com `#fragment` (tokens/erros do Supabase Auth na web).
Uri currentUriWithFragment() {
  try {
    return Uri.parse(html.window.location.href);
  } catch (_) {
    return Uri.base;
  }
}

/// Remove o `#...` da barra de endereço e deixa só o path (evita GoRouter tratar erro como rota).
void replaceBrowserPath(String path) {
  try {
    if (path.isEmpty) return;
    final p = path.startsWith('/') ? path : '/$path';
    html.window.history.replaceState(null, '', p);
  } catch (_) {}
}

const _kAuthErrKey = 'campanha_mt_supabase_auth_error';

void storePendingAuthErrorMessage(String message) {
  try {
    html.window.sessionStorage[_kAuthErrKey] = message;
  } catch (_) {}
}

String? takePendingAuthErrorMessage() {
  try {
    final storage = html.window.sessionStorage;
    final v = storage[_kAuthErrKey];
    if (v == null || v.isEmpty) return null;
    storage[_kAuthErrKey] = '';
    return v;
  } catch (_) {
    return null;
  }
}
