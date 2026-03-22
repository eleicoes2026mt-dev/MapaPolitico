import '../../../models/bandeira_visual.dart';

/// Dados do marcador de cidade no mapa (apoiadores + votantes), com opcional bandeira.
class MapaMarcadorCidade {
  const MapaMarcadorCidade({
    required this.quantidade,
    this.bandeiraVisual,
    this.bandeiraIniciais,
    this.bandeiraCorPrimariaHex,
    this.bandeiraEmoji,
  });

  final int quantidade;
  /// Bandeira completa (primeiro apoiador da cidade); preferir no mapa web.
  final BandeiraVisual? bandeiraVisual;
  final String? bandeiraIniciais;
  final String? bandeiraCorPrimariaHex;
  final String? bandeiraEmoji;
}
