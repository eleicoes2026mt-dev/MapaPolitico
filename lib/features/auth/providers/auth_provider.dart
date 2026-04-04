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

final profileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
  if (data == null) return null;
  return Profile.fromJson(data);
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
      final data = await _client.from('profiles').select().eq('id', uid).maybeSingle();
      if (data != null) {
        final ativo = data['ativo'] as bool? ?? true;
        if (!ativo) {
          await _client.auth.signOut();
          state = const AsyncValue.data(null);
          return;
        }
      }
      state = AsyncValue.data(data != null ? Profile.fromJson(data) : null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    clearProfileRoleCache();
    await _client.auth.signInWithPassword(email: email, password: password);
    final user = _client.auth.currentUser;
    if (user != null) {
      final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      final ativo = data?['ativo'] as bool? ?? true;
      if (!ativo) {
        await _client.auth.signOut();
        state = const AsyncValue.data(null);
        throw Exception('Sua conta foi desativada. Procure o candidato da campanha.');
      }
      state = AsyncValue.data(data != null ? Profile.fromJson(data) : null);
    }
  }

  Future<void> signUp(String email, String password, {String? fullName}) async {
    clearProfileRoleCache();
    await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null && fullName.isNotEmpty ? {'full_name': fullName} : null,
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
