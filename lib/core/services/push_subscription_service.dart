import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../supabase/supabase_provider.dart';
import 'pwa_service.dart';

/// VAPID public key — lida de EnvConfig (defaultValue já preenchida).
const _vapidPublicKey = EnvConfig.vapidPublicKey;

/// Resultado da inscrição push.
enum PushSubscribeResult { granted, denied, unsupported, alreadySubscribed, error }

class PushSubscriptionService {
  PushSubscriptionService._();
  static final instance = PushSubscriptionService._();

  /// Solicita permissão e registra a subscrição no Supabase.
  Future<PushSubscribeResult> enablePush(String profileId) async {
    if (!kIsWeb) return PushSubscribeResult.unsupported;
    if (_vapidPublicKey.isEmpty) {
      debugPrint('PushSubscriptionService: VAPID_PUBLIC_KEY não configurada. '
          'Gere em https://vapidkeys.com e passe com --dart-define=VAPID_PUBLIC_KEY=...');
      return PushSubscribeResult.unsupported;
    }

    final perm = await PwaService.instance.requestNotificationPermission();
    if (perm != 'granted') return PushSubscribeResult.denied;

    final existing = await PwaService.instance.currentSubscription();
    if (existing != null) {
      // Já existe — garante que está salvo no Supabase
      await _upsertSubscription(profileId, existing);
      return PushSubscribeResult.alreadySubscribed;
    }

    final subJson = await PwaService.instance.subscribeToPush(_vapidPublicKey);
    if (subJson == null) return PushSubscribeResult.error;

    await _upsertSubscription(profileId, subJson);
    return PushSubscribeResult.granted;
  }

  Future<bool> disablePush(String profileId) async {
    if (!kIsWeb) return false;
    final sub = await PwaService.instance.currentSubscription();
    if (sub != null) {
      try {
        final map = jsonDecode(sub) as Map<String, dynamic>;
        final endpoint = map['endpoint'] as String?;
        if (endpoint != null) {
          await supabase
              .from('push_subscriptions')
              .delete()
              .eq('profile_id', profileId)
              .eq('endpoint', endpoint);
        }
      } catch (_) {}
    }
    return PwaService.instance.unsubscribeFromPush();
  }

  Future<bool> isSubscribed(String profileId) async {
    if (!kIsWeb) return false;
    if (!PwaService.instance.notificationsGranted) return false;
    final sub = await PwaService.instance.currentSubscription();
    return sub != null;
  }

  Future<void> _upsertSubscription(String profileId, String subJson) async {
    try {
      final map = jsonDecode(subJson) as Map<String, dynamic>;
      final endpoint = map['endpoint'] as String?;
      final keys = map['keys'] as Map<String, dynamic>?;
      if (endpoint == null || keys == null) return;

      await supabase.from('push_subscriptions').upsert(
        {
          'profile_id': profileId,
          'endpoint': endpoint,
          'p256dh': keys['p256dh'] ?? '',
          'auth_key': keys['auth'] ?? '',
          'user_agent': kIsWeb ? 'web' : 'unknown',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'profile_id,endpoint',
      );
    } catch (e) {
      debugPrint('PushSubscriptionService._upsertSubscription error: $e');
    }
  }
}

/// Provider de estado: notificações ativas para o usuário atual.
final pushEnabledProvider = FutureProvider<bool>((ref) async {
  if (!kIsWeb) return false;
  final sub = await PwaService.instance.currentSubscription();
  return sub != null && PwaService.instance.notificationsGranted;
});
