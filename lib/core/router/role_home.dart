/// Primeira tela após login / convite, conforme o papel (não misturar painel do deputado com assessor/apoiador).
String homePathForProfileRole(String? role) {
  switch (role) {
    case 'assessor':
      return '/apoiadores';
    case 'apoiador':
      return '/votantes';
    case 'candidato':
    case 'votante':
    default:
      return '/';
  }
}
