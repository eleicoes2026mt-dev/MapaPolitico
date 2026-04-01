import 'dart:async';
import 'dart:js_interop';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

// ── Declarações JS externas ───────────────────────────────────────────────────

@JS('pwaCanInstall') external bool _jsCanInstall();
@JS('pwaIsInstalled') external bool _jsIsInstalled();
@JS('notifPermission') external String _jsNotifPermission();
@JS('notifRequestPermission') external JSPromise _jsRequestPermission();
@JS('pushSubscribe') external JSPromise _jsPushSubscribe(String vapidKey);
@JS('pushUnsubscribe') external JSPromise _jsPushUnsubscribe();
@JS('pushCurrentSubscription') external JSPromise _jsCurrentSubscription();
@JS('showLocalNotification') external void _jsShowLocal(String title, String body, String url);

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
    html.window.addEventListener('pwa-install-available', (_) => _installAvailableCtrl.add(true));
    html.window.addEventListener('pwa-app-installed', (_) => _installAvailableCtrl.add(false));
  }

  // ── Detecção ──────────────────────────────────────────────────────────────

  bool get isIOS {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    } catch (_) { return false; }
  }

  bool get isSafari {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('safari') && !ua.contains('chrome') && !ua.contains('chromium');
    } catch (_) { return false; }
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  bool get hasSeenOnboarding {
    try { return html.window.localStorage['pwa_onboarded'] == 'true'; }
    catch (_) { return false; }
  }

  void markOnboardingSeen() {
    try { html.window.localStorage['pwa_onboarded'] = 'true'; } catch (_) {}
  }

  // ── Install ───────────────────────────────────────────────────────────────

  bool get canInstall { try { return _jsCanInstall(); } catch (_) { return false; } }
  bool get isInstalled { try { return _jsIsInstalled(); } catch (_) { return false; } }

  /// Dispara o prompt de instalação. Retorna 'triggered', 'unavailable' ou 'error'.
  /// O resultado (accepted/dismissed) é tratado pelo evento 'pwa-app-installed'.
  Future<String> install() async {
    try {
      final result = js.context.callMethod('pwaInstall');
      return result != null ? 'triggered' : 'unavailable';
    } catch (_) { return 'unavailable'; }
  }

  // ── Notificações ──────────────────────────────────────────────────────────

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
