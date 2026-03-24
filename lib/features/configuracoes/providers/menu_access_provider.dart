import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';

/// Registra data/hora do último acesso à área Assessores ou Apoiadores (`register_menu_access`).
///
/// Não invalida [profileProvider]: isso refaz o fetch do perfil e reexecuta todos os
/// `FutureProvider`s que fazem `watch(profileProvider)`, gerando rajada de HTTP na web
/// (pilha em `browser_client.dart`) e sensação de travamento ao abrir Apoiadores/Assessores.
/// O subtítulo «último acesso» no menu atualiza no próximo login ou refresh completo.
final registerMenuAccessProvider = Provider<Future<void> Function(String menu)>((ref) {
  return (String menu) async {
    await supabase.rpc('register_menu_access', params: {'p_menu': menu});
  };
});
