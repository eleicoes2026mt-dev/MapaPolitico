import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../models/bandeira_visual.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../models/mapa_marcador_cidade.dart';

class _MarcadorAgg {
  int count = 0;
  BandeiraVisual? visual;
}

/// Monta mapa de marcadores por cidade (contagem + bandeira do apoiador que indicou).
Map<String, MapaMarcadorCidade> buildMarcadoresCidadesMap(
  List<Apoiador> apoiadores,
  List<Votante> votantes, {
  String? onlyApoiadorId,
}) {
  final aggs = <String, _MarcadorAgg>{};

  // Índice rápido: apoiador_id → Apoiador (para resolver bandeira dos votantes)
  final apoiadorById = {for (final a in apoiadores) a.id: a};

  void aplicarBandeira(_MarcadorAgg g, Apoiador a) {
    g.visual ??= a.bandeiraVisualResolvida;
  }

  for (final a in apoiadores) {
    if (onlyApoiadorId != null && a.id != onlyApoiadorId) continue;
    final cidade = a.cidadeParaMapa ?? a.cidadeNome;
    if (cidade == null || cidade.trim().isEmpty) continue;
    final key = normalizarNomeMunicipioMT(cidade);
    final g = aggs.putIfAbsent(key, _MarcadorAgg.new);
    g.count++;
    aplicarBandeira(g, a);
  }

  for (final v in votantes) {
    if (onlyApoiadorId != null && v.apoiadorId != onlyApoiadorId) continue;
    // Usa municipioNome (join) OU cidade_nome (texto livre) — o que estiver preenchido
    final nome = v.municipioNome ?? v.cidadeNome;
    if (nome == null || nome.trim().isEmpty) continue;
    final key = normalizarNomeMunicipioMT(nome);
    final g = aggs.putIfAbsent(key, _MarcadorAgg.new);
    g.count++;
    // Aplica a bandeira do apoiador que indicou o votante
    if (v.apoiadorId != null) {
      final ap = apoiadorById[v.apoiadorId];
      if (ap != null) aplicarBandeira(g, ap);
    }
  }

  return {
    for (final e in aggs.entries)
      e.key: MapaMarcadorCidade(
        quantidade: e.value.count,
        bandeiraVisual: e.value.visual,
        bandeiraIniciais: _trimOrNull(e.value.visual?.iniciais),
        bandeiraCorPrimariaHex: e.value.visual?.corPrimariaHex,
        bandeiraEmoji: _trimOrNull(e.value.visual?.emoji),
      ),
  };
}

String? _trimOrNull(String? s) {
  final t = s?.trim();
  if (t == null || t.isEmpty) return null;
  return t;
}

/// Mapa completo da campanha (sem filtros da tela Mapa). Usado em Estratégia e como base.
final cidadesMarcadoresMapaCampanhaProvider = Provider<Map<String, MapaMarcadorCidade>>((ref) {
  final apoiadores = ref.watch(apoiadoresListProvider).valueOrNull ?? [];
  final votantes = ref.watch(votantesListProvider).valueOrNull ?? [];
  return buildMarcadoresCidadesMap(apoiadores, votantes);
});

/// Compatível com código legado: só contagem por cidade (campanha inteira).
final cidadesComApoiadorProvider = Provider<Map<String, int>>((ref) {
  final m = ref.watch(cidadesMarcadoresMapaCampanhaProvider);
  return {for (final e in m.entries) e.key: e.value.quantidade};
});
