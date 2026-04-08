import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave legada (mantida para migração).
const _prefsKeyPontosLegacy = 'campanha_mapa_pontos_escala';
const _prefsKeyPontos = 'campanha_mapa_visual_pontos';
const _prefsKeyContorno = 'campanha_mapa_visual_contorno';

/// Limites dos controlos nas Configurações (50% … 200%).
const double kMapaVisualEscalaMin = 0.5;
const double kMapaVisualEscalaMax = 2.0;
const double kMapaVisualEscalaDefault = 1.0;

/// Preferências visuais do mapa: tamanho dos **marcadores** e espessura das **linhas de contorno** (regiões / MT).
@immutable
class MapaVisualPrefs {
  const MapaVisualPrefs({
    this.escalaPontos = kMapaVisualEscalaDefault,
    this.escalaContorno = kMapaVisualEscalaDefault,
  });

  final double escalaPontos;
  final double escalaContorno;

  MapaVisualPrefs copyWith({
    double? escalaPontos,
    double? escalaContorno,
  }) {
    return MapaVisualPrefs(
      escalaPontos: escalaPontos ?? this.escalaPontos,
      escalaContorno: escalaContorno ?? this.escalaContorno,
    );
  }
}

/// Estado persistido em [SharedPreferences] (por dispositivo). Use [commit] para gravar.
class MapaVisualPrefsNotifier extends StateNotifier<MapaVisualPrefs> {
  MapaVisualPrefsNotifier() : super(const MapaVisualPrefs()) {
    _load();
  }

  double _clampEscala(double v) =>
      v.clamp(kMapaVisualEscalaMin, kMapaVisualEscalaMax);

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      double? pontos = p.getDouble(_prefsKeyPontos);
      if (pontos == null) {
        pontos = p.getDouble(_prefsKeyPontosLegacy);
      }
      final contorno = p.getDouble(_prefsKeyContorno);
      state = MapaVisualPrefs(
        escalaPontos: _clampEscala(pontos ?? kMapaVisualEscalaDefault),
        escalaContorno: _clampEscala(contorno ?? kMapaVisualEscalaDefault),
      );
    } catch (_) {}
  }

  /// Grava no disco e atualiza o mapa em tempo real.
  Future<void> commit(MapaVisualPrefs prefs) async {
    final next = MapaVisualPrefs(
      escalaPontos: _clampEscala(prefs.escalaPontos),
      escalaContorno: _clampEscala(prefs.escalaContorno),
    );
    state = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_prefsKeyPontos, next.escalaPontos);
      await p.setDouble(_prefsKeyContorno, next.escalaContorno);
    } catch (_) {}
  }
}

final mapaVisualPrefsProvider =
    StateNotifierProvider<MapaVisualPrefsNotifier, MapaVisualPrefs>((ref) {
  return MapaVisualPrefsNotifier();
});
