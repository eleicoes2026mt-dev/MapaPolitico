// Na web usa placeholder (ArcGIS não suporta web). Em Android/iOS usa mapa ArcGIS.
export 'mapa_regional_widget_io.dart' if (dart.library.html) 'mapa_regional_widget_web.dart';
