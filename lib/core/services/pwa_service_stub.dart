import 'dart:async';

/// Stub para plataformas não-web — todos os métodos retornam valores seguros.
class PwaService {
  PwaService._();
  static final instance = PwaService._();

  Stream<bool> get onInstallAvailable => const Stream.empty();

  void init() {}
  bool get canInstall => false;
  bool get isInstalled => false;
  Future<String> install() async => 'unavailable';
  String get notificationPermission => 'denied';
  bool get notificationsGranted => false;
  Future<String> requestNotificationPermission() async => 'denied';
  Future<String?> subscribeToPush(String vapidPublicKey) async => null;
  Future<bool> unsubscribeFromPush() async => false;
  Future<String?> currentSubscription() async => null;
  void showLocal(String title, String body, {String? url}) {}
}
