import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/profile.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/router/profile_role_cache.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((e) => e.session?.user);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

String _profileSelectEmbed() =>
    '*, partidos (sigla, nome, bandeira_url)';

/// Busca [profiles] do utilizador. Se não existir linha (trigger de signup falhou),
/// cria uma mínima por upsert (RLS: `id` = [User.id]) e volta a ler.
Future<Profile?> fetchProfileForUser(User user) async {
  Map<String, dynamic>? row;
  try {
    final data = await supabase
        .from('profiles')
        .select(_profileSelectEmbed())
        .eq('id', user.id)
        .maybeSingle();
    if (data != null) {
      row = Map<String, dynamic>.from(data);
    }
  } on PostgrestException {
    rethrow;
  }

  if (row == null) {
    final email = user.email ?? '';
    final metaName = user.userMetadata?['full_name']?.toString().trim();
    final fullName = (metaName != null && metaName.isNotEmpty)
        ? metaName
        : (email.contains('@') ? email.split('@').first : 'Usuário');
    // Convite (Edge) envia `role` em user_metadata; sem isto o upsert criava só com default votante.
    final metaRole = user.userMetadata?['role']?.toString().trim().toLowerCase();
    const validRoles = {'candidato', 'assessor', 'apoiador', 'votante'};
    final payload = <String, dynamic>{
      'id': user.id,
      if (email.isNotEmpty) 'email': email,
      'full_name': fullName,
      'ativo': true,
    };
    if (metaRole != null && validRoles.contains(metaRole)) {
      payload['role'] = metaRole;
    }
    if (user.userMetadata?['cadastro_via_qr'] == true) {
      payload['cadastro_via_qr'] = true;
    }
    await supabase.from('profiles').upsert(
      payload,
      onConflict: 'id',
    );
    final again = await supabase
        .from('profiles')
        .select(_profileSelectEmbed())
        .eq('id', user.id)
        .maybeSingle();
    if (again == null) return null;
    row = Map<String, dynamic>.from(again);
  }

  return Profile.fromJson(row);
}

final profileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return fetchProfileForUser(user);
});

class AuthNotifier extends StateNotifier<AsyncValue<Profile?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  final _client = supabase;

  void _init() {
    final user = _client.auth.currentUser;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }
    _loadProfile(user.id);
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || user.id != uid) {
        state = const AsyncValue.data(null);
        return;
      }
      final profile = await fetchProfileForUser(user);
      if (profile != null && !profile.ativo) {
        await _client.auth.signOut();
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    clearProfileRoleCache();
    await _client.auth.signInWithPassword(email: email, password: password);
    final user = _client.auth.currentUser;
    if (user != null) {
      final profile = await fetchProfileForUser(user);
      if (profile != null && !profile.ativo) {
        await _client.auth.signOut();
        state = const AsyncValue.data(null);
        throw Exception('Sua conta foi desativada. Procure o candidato da campanha.');
      }
      state = AsyncValue.data(profile);
    }
  }

  Future<void> signUp(
    String email,
    String password, {
    String? fullName,
    bool cadastroAmigosGilberto = false,
  }) async {
    clearProfileRoleCache();
    final data = <String, dynamic>{};
    if (fullName != null && fullName.isNotEmpty) data['full_name'] = fullName;
    if (cadastroAmigosGilberto) {
      data['role'] = 'votante';
      data['cadastro_via_qr'] = true;
    }
    await _client.auth.signUp(
      email: email,
      password: password,
      data: data.isEmpty ? null : data,
    );
    final user = _client.auth.currentUser;
    if (user != null) await _loadProfile(user.id);
  }

  Future<void> signOut() async {
    clearProfileRoleCache();
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Profile?>>((ref) {
  return AuthNotifier();
});
