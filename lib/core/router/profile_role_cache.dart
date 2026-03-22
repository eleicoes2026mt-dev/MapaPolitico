import 'package:supabase_flutter/supabase_flutter.dart';

/// Evita repetir SELECT em todo redirect do GoRouter; limpar no logout.
String? _cachedUserId;
String? _cachedRole;

Future<String?> cachedProfileRole(String userId) async {
  if (_cachedUserId == userId && _cachedRole != null) return _cachedRole;
  try {
    final data = await Supabase.instance.client.from('profiles').select('role').eq('id', userId).maybeSingle();
    _cachedUserId = userId;
    _cachedRole = data?['role'] as String?;
    return _cachedRole;
  } catch (_) {
    return null;
  }
}

void clearProfileRoleCache() {
  _cachedUserId = null;
  _cachedRole = null;
}
