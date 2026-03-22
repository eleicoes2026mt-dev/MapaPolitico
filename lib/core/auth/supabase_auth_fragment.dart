/// Mensagem amigável a partir dos parâmetros do fragmento `#error=...` do Supabase Auth.
String messageForSupabaseAuthFragment(Map<String, String> params) {
  final code = params['error_code'] ?? '';
  final rawDesc = params['error_description'] ?? params['error'] ?? '';
  var desc = rawDesc;
  if (desc.isNotEmpty) {
    try {
      desc = Uri.decodeQueryComponent(desc.replaceAll('+', ' '));
    } catch (_) {}
  }
  switch (code) {
    case 'otp_expired':
      return 'O link do convite expirou ou já foi usado. Peça ao candidato um novo convite (Reenviar convite no painel) ou use «Esqueci minha senha» se já tiver conta.';
    case 'access_denied':
      if (desc.isNotEmpty) return desc;
      return 'Acesso negado por este link. Solicite um novo convite ou entre com e-mail e senha.';
    default:
      if (desc.isNotEmpty) return desc;
      return 'Não foi possível validar o link. Entre com e-mail e senha ou peça um novo convite.';
  }
}
