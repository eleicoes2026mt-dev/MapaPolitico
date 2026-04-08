import 'profile_role_cache.dart';

/// Primeira tela após login / convite, conforme o papel (não misturar painel do deputado com assessor/apoiador).
String homePathForProfileRole(String? role) {
  switch (role) {
    case 'assessor':
      return '/apoiadores';
    case 'apoiador':
    case 'votante':
      // Votante = cadastro pelo link Amigos do Gilberto: mesmo painel reduzido do apoiador.
      return '/apoiador-home';
    case 'candidato':
    default:
      return '/';
  }
}

/// Home com cache do Supabase: assessor **grau 1** vai ao dashboard como o candidato.
Future<String> homePathForUserId(String userId) async {
  final role = await cachedProfileRole(userId);
  if (role == 'assessor') {
    final gestao = await cachedPodeGestaoCampanhaCompleta(userId);
    return gestao ? '/' : '/apoiadores';
  }
  return homePathForProfileRole(role);
}
