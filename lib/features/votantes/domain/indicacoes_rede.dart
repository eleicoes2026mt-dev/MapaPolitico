import '../../../models/votante.dart';
import '../../mapa/data/mt_municipios_coords.dart';

/// Agrupa escritas diferentes («João Lemes», «JOAO LEMES») numa só chave.
String normalizarChaveIndicacao(String raw) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) return '';
  return normalizarNomeMunicipioMT(collapsed);
}

/// Índices para análise de indicações a partir dos votantes já carregados.
class IndicacoesRede {
  IndicacoesRede._({
    required this.rotuloPorChaveConvidador,
    required Map<String, List<Votante>> indicadosPorChaveConvidador,
  }) : _indicadosPorChaveConvidador = indicadosPorChaveConvidador;

  factory IndicacoesRede.fromVotantes(List<Votante> votantes) {
    final rotulo = <String, String>{};

    void registrarRotulo(String? texto) {
      if (texto == null) return;
      final t = texto.trim();
      if (t.isEmpty) return;
      final k = normalizarChaveIndicacao(t);
      if (k.isEmpty) return;
      final existente = rotulo[k];
      if (existente == null || t.runes.length >= existente.runes.length) {
        rotulo[k] = t;
      }
    }

    final porConvidador = <String, List<Votante>>{};

    for (final v in votantes) {
      registrarRotulo(v.nome);
      registrarRotulo(v.convitePorNome);
      final conv = v.convitePorNome?.trim();
      if (conv == null || conv.isEmpty) continue;
      final k = normalizarChaveIndicacao(conv);
      if (k.isEmpty) continue;
      porConvidador.putIfAbsent(k, () => []).add(v);
    }

    for (final e in porConvidador.entries) {
      for (final v in e.value) {
        registrarRotulo(v.nome);
      }
    }

    return IndicacoesRede._(
      rotuloPorChaveConvidador: rotulo,
      indicadosPorChaveConvidador: porConvidador,
    );
  }

  /// Rótulos para exibir (forma mais completa vista nos cadastros).
  final Map<String, String> rotuloPorChaveConvidador;

  final Map<String, List<Votante>> _indicadosPorChaveConvidador;

  /// Convidadores que aparecem na coluna Indicação (ao menos uma pessoa ligada).
  Iterable<String> get chavesConvidadoresComIndicados =>
      _indicadosPorChaveConvidador.keys;

  int get totalConvidadoresComIndicacoesRegistradas => _indicadosPorChaveConvidador.length;

  /// Cópia mutável dos votantes cuja «Indicação» corresponde a [chaveConvidador].
  List<Votante> indicadosDiretosDe(String chaveConvidador) =>
      List<Votante>.from(_indicadosPorChaveConvidador[chaveConvidador] ?? const []);

  int contagemIndicacaoDireta(String chaveConvidador) =>
      _indicadosPorChaveConvidador[chaveConvidador]?.length ?? 0;

  int votosIndicacaoDireta(String chaveConvidador) {
    final list = _indicadosPorChaveConvidador[chaveConvidador];
    if (list == null) return 0;
    var s = 0;
    for (final v in list) {
      s += v.qtdVotosFamilia;
    }
    return s;
  }

  String rotuloExibir(String chaveConvidador) =>
      rotuloPorChaveConvidador[chaveConvidador] ?? chaveConvidador;

  /// Pessoas e votos na subárvore (indicados + indicados dos indicados, etc.).
  ({int pessoasNaRede, int votosNaRede}) alcanceSubarvore(String chaveRaizConvidador) {
    return _accumSubarvore(chaveRaizConvidador, <String>{});
  }

  ({int pessoasNaRede, int votosNaRede}) _accumSubarvore(
    String chaveConvidador,
    Set<String> caminhoParaEvitarCiclo,
  ) {
    if (chaveConvidador.isEmpty) {
      return (pessoasNaRede: 0, votosNaRede: 0);
    }
    if (caminhoParaEvitarCiclo.contains(chaveConvidador)) {
      return (pessoasNaRede: 0, votosNaRede: 0);
    }
    final nextPath = {...caminhoParaEvitarCiclo, chaveConvidador};
    final diretos = _indicadosPorChaveConvidador[chaveConvidador];
    if (diretos == null || diretos.isEmpty) {
      return (pessoasNaRede: 0, votosNaRede: 0);
    }
    var pessoas = diretos.length;
    var votos = 0;
    for (final v in diretos) {
      votos += v.qtdVotosFamilia;
      final ck = normalizarChaveIndicacao(v.nome);
      final sub = _accumSubarvore(ck, nextPath);
      pessoas += sub.pessoasNaRede;
      votos += sub.votosNaRede;
    }
    return (pessoasNaRede: pessoas, votosNaRede: votos);
  }

  List<String> rankingConvidadores({String filtroNome = ''}) {
    final q = normalizarChaveIndicacao(filtroNome);
    final keys = chavesConvidadoresComIndicados.toList();
    keys.sort((a, b) {
      final cmp = contagemIndicacaoDireta(b).compareTo(contagemIndicacaoDireta(a));
      if (cmp != 0) return cmp;
      return rotuloExibir(a).compareTo(rotuloExibir(b));
    });
    if (q.isEmpty) return keys;
    return keys.where((k) => k.contains(q) || rotuloExibir(k).toUpperCase().contains(q)).toList();
  }

  List<Votante> votantesSemIndicacao(List<Votante> todos) {
    return todos.where((v) {
      final c = v.convitePorNome?.trim();
      return c == null || c.isEmpty;
    }).toList();
  }

  List<Votante> votantesComIndicacao(List<Votante> todos) =>
      todos.where((v) => v.convitePorNome != null && v.convitePorNome!.trim().isNotEmpty).toList();
}
