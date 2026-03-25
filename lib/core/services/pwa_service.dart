// Exporta a implementação correta de PwaService por plataforma.
// Web → pwa_service_web.dart | Mobile/Desktop → pwa_service_stub.dart
export 'pwa_service_stub.dart'
    if (dart.library.html) 'pwa_service_web.dart';
