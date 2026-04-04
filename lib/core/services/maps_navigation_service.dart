import 'package:url_launcher/url_launcher.dart';

/// Abre o Google Maps com rota até o destino (app ou web).
Future<bool> openGoogleMapsDestination({
  required double lat,
  required double lng,
}) async {
  final u = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );
  return launchUrl(u, mode: LaunchMode.externalApplication);
}

/// Abre o Waze com navegação até o ponto.
Future<bool> openWazeDestination({required double lat, required double lng}) async {
  final u = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
  return launchUrl(u, mode: LaunchMode.externalApplication);
}

/// Fallback: busca por texto (sem coordenadas salvas).
Future<bool> openGoogleMapsSearchQuery(String query) async {
  final u = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
  );
  return launchUrl(u, mode: LaunchMode.externalApplication);
}
