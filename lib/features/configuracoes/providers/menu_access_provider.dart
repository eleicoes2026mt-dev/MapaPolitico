import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Registra data/hora do último acesso à área Assessores ou Apoiadores (`register_menu_access`).
final registerMenuAccessProvider = Provider<Future<void> Function(String menu)>((ref) {
  return (String menu) async {
    await supabase.rpc('register_menu_access', params: {'p_menu': menu});
    ref.invalidate(profileProvider);
  };
});
