import 'package:supabase_flutter/supabase_flutter.dart';

/// Evita repetir SELECT em todo redirect do GoRouter; limpar no logout.
String? _cachedUserId;
String? _cachedRole;
bool? _cachedGestaoCompleta;

Future<String?> cachedProfileRole(String userId) async {
  if (_cachedUserId == userId && _cachedRole != null) return _cachedRole;
  await _loadProfileGestaoCache(userId);
  return _cachedRole;
}

/// Candidato ou assessor com grau 1 (para redirect de rotas de gestão).
Future<bool> cachedPodeGestaoCampanhaCompleta(String userId) async {
  if (_cachedUserId == userId && _cachedGestaoCompleta != null) {
    return _cachedGestaoCompleta!;
  }
  await _loadProfileGestaoCache(userId);
  return _cachedGestaoCompleta ?? false;
}

Future<void> _loadProfileGestaoCache(String userId) async {
  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('role, assessores(grau_acesso)')
        .eq('id', userId)
        .maybeSingle();
    _cachedUserId = userId;
    _cachedRole = data?['role'] as String?;
    _cachedGestaoCompleta = _computeGestaoCompleta(data);
  } catch (_) {
    _cachedUserId = userId;
    _cachedRole = null;
    _cachedGestaoCompleta = false;
  }
}

bool _computeGestaoCompleta(Map<String, dynamic>? data) {
  if (data == null) return false;
  final role = (data['role'] as String?)?.toLowerCase();
  if (role == 'candidato') return true;
  if (role != 'assessor') return false;
  final a = data['assessores'];
  if (a is List && a.isNotEmpty) {
    final g = (a.first as Map)['grau_acesso'];
    if (g is num) return g.toInt() == 1;
  }
  return false;
}

void clearProfileRoleCache() {
  _cachedUserId = null;
  _cachedRole = null;
  _cachedGestaoCompleta = null;
}
