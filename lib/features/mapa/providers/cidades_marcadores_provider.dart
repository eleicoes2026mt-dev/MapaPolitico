import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../models/assessor.dart';
import '../../../models/bandeira_visual.dart';
import '../../../models/municipio.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../assessores/providers/assessores_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../models/mapa_marcador_cidade.dart';

/// Lista de apoiadores para o mapa: candidato/assessor veem todos;
/// apoiador logado vê só o próprio registro (para exibir o marcador).
final apoiadoresParaMapaProvider = FutureProvider<List<Apoiador>>((ref) async {
  final lista = ref.watch(apoiadoresListProvider).valueOrNull ?? [];
  if (lista.isNotEmpty) return lista;
  final profile = await ref.read(profileProvider.future);
  if (profile?.role != 'apoiador') return [];
  final eu = ref.watch(meuApoiadorProvider).valueOrNull;
  return eu != null ? [eu] : [];
});

enum _PinNivel {
  assessor,
  apoiador,
  amigoCandidato,
  amigoAssessor,
  amigoApoiador,
  qr,
}

int _prioridadeNivel(_PinNivel n) {
  switch (n) {
    case _PinNivel.assessor:
      return 20;
    case _PinNivel.apoiador:
      return 30;
    case _PinNivel.amigoCandidato:
      return 40;
    case _PinNivel.amigoAssessor:
      return 45;
    case _PinNivel.amigoApoiador:
      return 50;
    case _PinNivel.qr:
      return 60;
  }
}

BandeiraVisual _bandeiraNivel(_PinNivel n) {
  switch (n) {
    case _PinNivel.assessor:
      return BandeiraVisual.mapaAssessor();
    case _PinNivel.apoiador:
      return BandeiraVisual.mapaApoiador();
    case _PinNivel.amigoCandidato:
      return BandeiraVisual.mapaAmigoCandidato();
    case _PinNivel.amigoAssessor:
      return BandeiraVisual.mapaAmigoPorAssessor();
    case _PinNivel.amigoApoiador:
      return BandeiraVisual.mapaAmigoPorApoiador();
    case _PinNivel.qr:
      return BandeiraVisual.mapaCadastroQr();
  }
}

_PinNivel _nivelParaVotante(Votante v) {
  if (v.cadastroViaQr) return _PinNivel.qr;
  if (v.apoiadorId != null && v.apoiadorId!.isNotEmpty) return _PinNivel.amigoApoiador;
  if (v.cadastradoPeloCandidato) return _PinNivel.amigoCandidato;
  if (v.assessorId != null && v.assessorId!.isNotEmpty) return _PinNivel.amigoAssessor;
  return _PinNivel.amigoCandidato;
}

class _MarcadorAgg {
  int count = 0;
  _PinNivel? melhorNivel;
  BandeiraVisual? get visual => melhorNivel == null ? null : _bandeiraNivel(melhorNivel!);

  void considerar(_PinNivel n) {
    count++;
    if (melhorNivel == null || _prioridadeNivel(n) > _prioridadeNivel(melhorNivel!)) {
      melhorNivel = n;
    }
  }
}

String? _trimOrNull(String? s) {
  final t = s?.trim();
  if (t == null || t.isEmpty) return null;
  return t;
}

String? _nomeMunicipioPorId(List<Municipio> munList, String? id) {
  if (id == null || id.isEmpty) return null;
  for (final m in munList) {
    if (m.id == id) return m.nome;
  }
  return null;
}

/// Monta agregação por cidade (usado com filtros do mapa e campanha completa).
Map<String, MapaMarcadorCidade> buildMarcadoresCidadesMap(
  List<Apoiador> apoiadores,
  List<Votante> votantes, {
  List<Assessor> assessores = const [],
  List<Municipio> munList = const [],
  String? onlyApoiadorId,
}) {
  final ap = onlyApoiadorId != null ? apoiadores.where((a) => a.id == onlyApoiadorId).toList() : apoiadores;
  final vt = onlyApoiadorId != null ? votantes.where((v) => v.apoiadorId == onlyApoiadorId).toList() : votantes;
  final asr = onlyApoiadorId != null ? <Assessor>[] : assessores;

  final aggs = <String, _MarcadorAgg>{};

  void touch(String key, _PinNivel n) {
    aggs.putIfAbsent(key, _MarcadorAgg.new).considerar(n);
  }

  for (final a in ap) {
    final cidade = a.cidadeParaMapa ?? a.cidadeNome;
    if (cidade == null || cidade.trim().isEmpty) continue;
    touch(normalizarNomeMunicipioMT(cidade), _PinNivel.apoiador);
  }

  for (final s in asr) {
    if (!s.ativo) continue;
    final nome = _nomeMunicipioPorId(munList, s.municipioId);
    if (nome == null || nome.trim().isEmpty) continue;
    touch(normalizarNomeMunicipioMT(nome), _PinNivel.assessor);
  }

  for (final v in vt) {
    final nome = v.municipioNome ?? v.cidadeNome;
    if (nome == null || nome.trim().isEmpty) continue;
    touch(normalizarNomeMunicipioMT(nome), _nivelParaVotante(v));
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

/// Mapa completo da campanha (cores fixas por tipo — não usa editor de bandeira do apoiador).
final cidadesMarcadoresMapaCampanhaProvider = Provider<Map<String, MapaMarcadorCidade>>((ref) {
  return buildMarcadoresCidadesMap(
    ref.watch(apoiadoresParaMapaProvider).valueOrNull ?? [],
    ref.watch(votantesListProvider).valueOrNull ?? [],
    assessores: ref.watch(assessoresListProvider).valueOrNull ?? [],
    munList: ref.watch(municipiosMTListProvider).valueOrNull ?? [],
  );
});

/// Compatível com código legado: só contagem por cidade (campanha inteira).
final cidadesComApoiadorProvider = Provider<Map<String, int>>((ref) {
  final m = ref.watch(cidadesMarcadoresMapaCampanhaProvider);
  return {for (final e in m.entries) e.key: e.value.quantidade};
});
