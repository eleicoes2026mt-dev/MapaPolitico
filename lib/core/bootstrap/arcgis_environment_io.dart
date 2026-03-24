import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

/// O SDK exige [ArcGISEnvironment.apiKey] para serviços/basemaps ArcGIS (ver tutoriais Esri).
void initArcgisEnvironment() {
  const k = EnvConfig.arcgisApiKey;
  if (k.isNotEmpty) {
    ArcGISEnvironment.apiKey = k;
  } else if (kDebugMode) {
    debugPrint(
      'AVISO: ARCGIS_API_KEY vazia. Defina com --dart-define=ARCGIS_API_KEY=... ou o mapa pode fechar o app.',
    );
  }
}
