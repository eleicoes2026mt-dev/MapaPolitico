import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtros opcionais do mapa regional (tela Mapa).
class MapaFiltros {
  const MapaFiltros({
    this.cidadeKey,
    this.regiaoCdRgint,
    this.apoiadorId,
    this.topBenfeitoriasMunicipios = 0,
  });

  /// Chave normalizada do município (`normalizarNomeMunicipioMT`).
  final String? cidadeKey;

  /// Região intermediária (5101–5105).
  final String? regiaoCdRgint;

  /// Mostrar apenas rede deste apoiador (estimativa + marcadores).
  final String? apoiadorId;

  /// 0 = desligado. >0 = restringe a N municípios com mais benfeitorias (contagem).
  final int topBenfeitoriasMunicipios;
}

class MapaFiltrosNotifier extends StateNotifier<MapaFiltros> {
  MapaFiltrosNotifier() : super(const MapaFiltros());

  void setCidade(String? key) => state = MapaFiltros(
        cidadeKey: key,
        regiaoCdRgint: state.regiaoCdRgint,
        apoiadorId: state.apoiadorId,
        topBenfeitoriasMunicipios: state.topBenfeitoriasMunicipios,
      );

  void setRegiao(String? cdRgint) => state = MapaFiltros(
        cidadeKey: state.cidadeKey,
        regiaoCdRgint: (cdRgint == null || cdRgint.isEmpty) ? null : cdRgint,
        apoiadorId: state.apoiadorId,
        topBenfeitoriasMunicipios: state.topBenfeitoriasMunicipios,
      );

  void setApoiador(String? id) => state = MapaFiltros(
        cidadeKey: state.cidadeKey,
        regiaoCdRgint: state.regiaoCdRgint,
        apoiadorId: id,
        topBenfeitoriasMunicipios: state.topBenfeitoriasMunicipios,
      );

  void setTopBenfeitorias(int n) => state = MapaFiltros(
        cidadeKey: state.cidadeKey,
        regiaoCdRgint: state.regiaoCdRgint,
        apoiadorId: state.apoiadorId,
        topBenfeitoriasMunicipios: n < 0 ? 0 : n,
      );

  void limpar() => state = const MapaFiltros();
}

final mapaFiltrosProvider = StateNotifierProvider<MapaFiltrosNotifier, MapaFiltros>((ref) {
  return MapaFiltrosNotifier();
});
