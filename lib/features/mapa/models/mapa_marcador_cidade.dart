/// Dados do marcador de cidade no mapa (apoiadores + votantes), com opcional bandeira.
class MapaMarcadorCidade {
  const MapaMarcadorCidade({
    required this.quantidade,
    this.bandeiraIniciais,
    this.bandeiraCorPrimariaHex,
    this.bandeiraEmoji,
  });

  final int quantidade;
  final String? bandeiraIniciais;
  final String? bandeiraCorPrimariaHex;
  final String? bandeiraEmoji;
}
