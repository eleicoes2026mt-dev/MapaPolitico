import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'mt_municipios_coords.dart';

/// Faixas de votos TSE no mapa: vermelho (menos) → laranja → azul → verde (mais).
enum TseVotoTier {
  baixo, // vermelho
  medioBaixo, // laranja
  medioAlto, // azul
  alto; // verde

  String get tituloCurto {
    switch (this) {
      case TseVotoTier.baixo:
        return 'Menos votos';
      case TseVotoTier.medioBaixo:
        return 'Abaixo da média';
      case TseVotoTier.medioAlto:
        return 'Acima da média';
      case TseVotoTier.alto:
        return 'Mais votos';
    }
  }

  String get tituloLegenda {
    switch (this) {
      case TseVotoTier.baixo:
        return 'Vermelho — menos votados';
      case TseVotoTier.medioBaixo:
        return 'Laranja — faixa intermediária';
      case TseVotoTier.medioAlto:
        return 'Azul — faixa alta';
      case TseVotoTier.alto:
        return 'Verde — mais votados';
    }
  }
}

/// Cor sólida do centro do círculo (TSE).
/// Proporção **0 → 1** (menos → mais votos) para tamanho/cor das bolhas no mapa.
/// Com [maxV/minV] ≥ 8 usa escala **logarítmica** para não “achatar” todas as cidades
/// quando há uma capital com muitos votos e o restante com poucos.
double proporcaoVisualVotos(int votos, int minV, int maxV) {
  if (maxV <= minV) return 1.0;
  final ratio = maxV / math.max(minV, 1);
  if (ratio >= 8) {
    final logMin = math.log(minV + 1.0);
    final logMax = math.log(maxV + 1.0);
    final logV = math.log(votos + 1.0);
    if (logMax <= logMin) return 1.0;
    return ((logV - logMin) / (logMax - logMin)).clamp(0.0, 1.0);
  }
  return ((votos - minV) / (maxV - minV)).clamp(0.0, 1.0);
}

/// Cor contínua da bolha TSE: vermelho (menos votos) → verde (mais votos).
Color corHeatmapVotos(int votos, int minV, int maxV) {
  final t = proporcaoVisualVotos(votos, minV, maxV);
  return Color.lerp(
    const Color(0xFFB71C1C),
    const Color(0xFF2E7D32),
    t,
  )!;
}

Color corCentroTier(TseVotoTier tier) {
  switch (tier) {
    case TseVotoTier.baixo:
      return const Color(0xFFE53935);
    case TseVotoTier.medioBaixo:
      return const Color(0xFFFB8C00);
    case TseVotoTier.medioAlto:
      return const Color(0xFF1E88E5);
    case TseVotoTier.alto:
      return const Color(0xFF43A047);
  }
}

/// Divide [minV, maxV] em 4 faixas iguais (largura).
TseVotoTier tierParaVotos(int votos, int minV, int maxV) {
  if (maxV <= minV) return TseVotoTier.alto;
  final range = maxV - minV;
  final t = (votos - minV) / range;
  if (t < 0.25) return TseVotoTier.baixo;
  if (t < 0.50) return TseVotoTier.medioBaixo;
  if (t < 0.75) return TseVotoTier.medioAlto;
  return TseVotoTier.alto;
}

String textoFaixaVotos(TseVotoTier tier, int minV, int maxV) {
  if (maxV <= minV) {
    return 'Todas as cidades com o mesmo valor ($minV votos).';
  }
  final range = maxV - minV;
  final a = minV + (range * _inicioTier(tier)).round();
  final b = minV + (range * _fimTier(tier)).round();
  return '$a a $b votos (TSE 2022)';
}

double _inicioTier(TseVotoTier t) {
  switch (t) {
    case TseVotoTier.baixo:
      return 0;
    case TseVotoTier.medioBaixo:
      return 0.25;
    case TseVotoTier.medioAlto:
      return 0.50;
    case TseVotoTier.alto:
      return 0.75;
  }
}

double _fimTier(TseVotoTier t) {
  switch (t) {
    case TseVotoTier.baixo:
      return 0.25;
    case TseVotoTier.medioBaixo:
      return 0.50;
    case TseVotoTier.medioAlto:
      return 0.75;
    case TseVotoTier.alto:
      return 1.0;
  }
}

/// Lista cidades (chave normalizada) com votos na faixa [tier], ordenadas por votos decrescente.
List<({String key, int votos})> cidadesNoTier(
  Map<String, int> votosPorCidade,
  TseVotoTier tier,
  int minV,
  int maxV,
) {
  final out = <({String key, int votos})>[];
  for (final e in votosPorCidade.entries) {
    if (tierParaVotos(e.value, minV, maxV) == tier) {
      out.add((key: e.key, votos: e.value));
    }
  }
  out.sort((a, b) => b.votos.compareTo(a.votos));
  return out;
}

({int minV, int maxV}) minMaxVotos(Map<String, int> votos) {
  if (votos.isEmpty) return (minV: 0, maxV: 0);
  var minV = 1 << 30;
  var maxV = 0;
  for (final v in votos.values) {
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  return (minV: minV, maxV: maxV);
}

String nomeExibicaoCidadeTse(String keyNormalizada) => displayNomeCidadeMT(keyNormalizada);
