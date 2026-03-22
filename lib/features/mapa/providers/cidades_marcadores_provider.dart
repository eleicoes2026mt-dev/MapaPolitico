import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../models/mapa_marcador_cidade.dart';

class _MarcadorAgg {
  int count = 0;
  String? iniciais;
  String? corHex;
  String? emoji;
}

/// Monta mapa de marcadores por cidade (contagem + primeira bandeira encontrada por apoiador).
Map<String, MapaMarcadorCidade> buildMarcadoresCidadesMap(
  List<Apoiador> apoiadores,
  List<Votante> votantes, {
  String? onlyApoiadorId,
}) {
  final aggs = <String, _MarcadorAgg>{};

  void aplicarBandeira(_MarcadorAgg g, Apoiador a) {
    final ini = a.bandeiraIniciais?.trim();
    if (ini != null && ini.isNotEmpty && (g.iniciais == null || g.iniciais!.isEmpty)) {
      g.iniciais = ini.length > 3 ? ini.substring(0, 3) : ini;
    }
    final cor = a.bandeiraCorPrimaria?.trim();
    if (cor != null && cor.isNotEmpty && (g.corHex == null || g.corHex!.isEmpty)) {
      g.corHex = cor.startsWith('#') ? cor : '#$cor';
    }
    final em = a.bandeiraEmoji?.trim();
    if (em != null && em.isNotEmpty && (g.emoji == null || g.emoji!.isEmpty)) {
      g.emoji = em;
    }
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
    final nome = v.municipioNome;
    if (nome == null || nome.trim().isEmpty) continue;
    final key = normalizarNomeMunicipioMT(nome);
    final g = aggs.putIfAbsent(key, _MarcadorAgg.new);
    g.count++;
  }

  return {
    for (final e in aggs.entries)
      e.key: MapaMarcadorCidade(
        quantidade: e.value.count,
        bandeiraIniciais: e.value.iniciais,
        bandeiraCorPrimariaHex: e.value.corHex,
        bandeiraEmoji: e.value.emoji,
      ),
  };
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
