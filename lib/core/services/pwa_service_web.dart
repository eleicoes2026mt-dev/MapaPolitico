import 'dart:async';
import 'dart:js_interop';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ── Declarações JS externas (dart:js_interop) ────────────────────────────────

@JS('pwaCanInstall')
external bool _jsCanInstall();

@JS('pwaIsInstalled')
external bool _jsIsInstalled();

@JS('pwaInstall')
external JSPromise _jsInstall();

@JS('notifPermission')
external String _jsNotifPermission();

@JS('notifRequestPermission')
external JSPromise _jsRequestPermission();

@JS('pushSubscribe')
external JSPromise _jsPushSubscribe(String vapidKey);

@JS('pushUnsubscribe')
external JSPromise _jsPushUnsubscribe();

@JS('pushCurrentSubscription')
external JSPromise _jsCurrentSubscription();

@JS('showLocalNotification')
external void _jsShowLocal(String title, String body, String url);

// ── PwaService (implementação web real) ──────────────────────────────────────

class PwaService {
  PwaService._();
  static final instance = PwaService._();

  final _installAvailableCtrl = StreamController<bool>.broadcast();
  Stream<bool> get onInstallAvailable => _installAvailableCtrl.stream;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    // Escuta eventos customizados disparados pelo index.html em vez de usar allowInterop
    html.window.addEventListener('pwa-install-available', (e) {
      _installAvailableCtrl.add(true);
    });
    html.window.addEventListener('pwa-app-installed', (e) {
      _installAvailableCtrl.add(false);
    });
  }

  bool get canInstall {
    try { return _jsCanInstall(); } catch (_) { return false; }
  }

  bool get isInstalled {
    try { return _jsIsInstalled(); } catch (_) { return false; }
  }

  Future<String> install() async {
    try {
      final result = await _jsInstall().toDart;
      return result?.dartify()?.toString() ?? 'dismissed';
    } catch (_) { return 'unavailable'; }
  }

  String get notificationPermission {
    try { return _jsNotifPermission(); } catch (_) { return 'default'; }
  }

  bool get notificationsGranted => notificationPermission == 'granted';

  Future<String> requestNotificationPermission() async {
    try {
      final result = await _jsRequestPermission().toDart;
      return result?.dartify()?.toString() ?? 'denied';
    } catch (_) { return 'denied'; }
  }

  Future<String?> subscribeToPush(String vapidPublicKey) async {
    if (vapidPublicKey.isEmpty) return null;
    try {
      final result = await _jsPushSubscribe(vapidPublicKey).toDart;
      return result?.dartify()?.toString();
    } catch (_) { return null; }
  }

  Future<bool> unsubscribeFromPush() async {
    try {
      final result = await _jsPushUnsubscribe().toDart;
      return result?.dartify() == true;
    } catch (_) { return false; }
  }

  Future<String?> currentSubscription() async {
    try {
      final result = await _jsCurrentSubscription().toDart;
      return result?.dartify()?.toString();
    } catch (_) { return null; }
  }

  void showLocal(String title, String body, {String? url}) {
    if (!notificationsGranted) return;
    try { _jsShowLocal(title, body, url ?? '/'); } catch (_) {}
  }
}
