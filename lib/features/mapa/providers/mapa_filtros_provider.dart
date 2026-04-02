import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quais dados compõem a estimativa de votos exibida no mapa.
enum FonteEstimativaMapa {
  /// Votantes + apoiadores.
  todos,
  /// Apenas votantes cadastrados.
  apenasVotantes,
  /// Apenas apoiadores.
  apenasApoiadores,
}

/// Filtros opcionais do mapa regional (tela Mapa).
class MapaFiltros {
  const MapaFiltros({
    this.cidadeKey,
    this.regiaoCdRgint,
    this.apoiadorId,
    this.topBenfeitoriasMunicipios = 0,
    // Padrão LIMPO — o usuário liga o que quiser ver
    this.mostrarTSE = false,
    this.mostrarMarcadores = false,
    this.fonteEstimativa = FonteEstimativaMapa.todos,
  });

  /// Chave normalizada do município.
  final String? cidadeKey;

  /// Região intermediária (5101–5105).
  final String? regiaoCdRgint;

  /// Mostrar apenas rede deste apoiador.
  final String? apoiadorId;

  /// 0 = desligado. >0 = top N municípios com mais benfeitorias.
  final int topBenfeitoriasMunicipios;

  /// Círculos de votos TSE (eleição passada) — desligado por padrão.
  final bool mostrarTSE;

  /// Marcadores de apoiadores/votantes — desligado por padrão.
  final bool mostrarMarcadores;

  /// Quais dados incluir no cálculo da estimativa da campanha.
  final FonteEstimativaMapa fonteEstimativa;

  MapaFiltros copyWith({
    Object? cidadeKey = _sentinel,
    Object? regiaoCdRgint = _sentinel,
    Object? apoiadorId = _sentinel,
    int? topBenfeitoriasMunicipios,
    bool? mostrarTSE,
    bool? mostrarMarcadores,
    FonteEstimativaMapa? fonteEstimativa,
  }) {
    return MapaFiltros(
      cidadeKey: cidadeKey == _sentinel ? this.cidadeKey : cidadeKey as String?,
      regiaoCdRgint:
          regiaoCdRgint == _sentinel ? this.regiaoCdRgint : regiaoCdRgint as String?,
      apoiadorId: apoiadorId == _sentinel ? this.apoiadorId : apoiadorId as String?,
      topBenfeitoriasMunicipios: topBenfeitoriasMunicipios ?? this.topBenfeitoriasMunicipios,
      mostrarTSE: mostrarTSE ?? this.mostrarTSE,
      mostrarMarcadores: mostrarMarcadores ?? this.mostrarMarcadores,
      fonteEstimativa: fonteEstimativa ?? this.fonteEstimativa,
    );
  }
}

const _sentinel = Object();

class MapaFiltrosNotifier extends StateNotifier<MapaFiltros> {
  MapaFiltrosNotifier() : super(const MapaFiltros());

  void setCidade(String? key) => state = state.copyWith(cidadeKey: key);
  void setRegiao(String? cdRgint) =>
      state = state.copyWith(regiaoCdRgint: (cdRgint == null || cdRgint.isEmpty) ? null : cdRgint);
  void setApoiador(String? id) => state = state.copyWith(apoiadorId: id);
  void setTopBenfeitorias(int n) =>
      state = state.copyWith(topBenfeitoriasMunicipios: n < 0 ? 0 : n);
  void toggleTSE() => state = state.copyWith(mostrarTSE: !state.mostrarTSE);
  void toggleMarcadores() => state = state.copyWith(mostrarMarcadores: !state.mostrarMarcadores);
  void setFonteEstimativa(FonteEstimativaMapa f) => state = state.copyWith(fonteEstimativa: f);
  void limpar() => state = const MapaFiltros();
}

final mapaFiltrosProvider = StateNotifierProvider<MapaFiltrosNotifier, MapaFiltros>((ref) {
  return MapaFiltrosNotifier();
});
