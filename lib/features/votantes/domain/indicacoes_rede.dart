import '../../../models/votante.dart';
import '../../../core/constants/amigos_gilberto.dart';
import '../../mapa/data/mt_municipios_coords.dart';

/// Agrupa escritas diferentes («João Lemes», «JOAO LEMES») numa só chave.
String normalizarChaveIndicacao(String raw) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) return '';
  return normalizarNomeMunicipioMT(collapsed);
}

/// Igual à coluna «Indicação» na lista Amigos do Gilberto: convite gravado → apoiador → candidato fallback.
/// Vale para **todo** cadastro (`Votante`); não há regras especiais por nome — Oberdan/outros são apenas exemplos na UI.
/// [apoiadorIdParaNome]: `id` do apoiador → nome como na tabela de apoiadores.
String textoIndicacaoResolvidoAmigosGilberto(
  Votante v,
  Map<String, String> apoiadorIdParaNome,
) {
  final c = v.convitePorNome?.trim();
  if (c != null && c.isNotEmpty) return c;
  if (v.apoiadorId != null) {
    final n = apoiadorIdParaNome[v.apoiadorId!]?.trim();
    if (n != null && n.isNotEmpty) return n;
  }
  return kIndicacaoListaFallbackCandidato;
}

/// Índices para análise de indicações a partir dos votantes já carregados.
class IndicacoesRede {
  /// Rede onde **cada** votante entra obrigatoriamente por um pai lógico (mesmo que `convite_por_nome`
  /// esteja vazio na base): [textoIndicacaoResolvidoAmigosGilberto].
  ///
  /// - convite gravado prevalece sobre o nome do apoiador;
  /// - senão vale o nome do apoiador (via [apoiadorIdParaNome]);
  /// - senão cai em [kIndicacaoListaFallbackCandidato] (Gilberto).
  factory IndicacoesRede.fromVotantes(
    List<Votante> votantes, {
    Map<String, String> apoiadorIdParaNome = const {},
  }) {
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
      final paiTexto =
          textoIndicacaoResolvidoAmigosGilberto(v, apoiadorIdParaNome);
      registrarRotulo(paiTexto);
      final k = normalizarChaveIndicacao(paiTexto);
      if (k.isEmpty) continue;
      porConvidador.putIfAbsent(k, () => []).add(v);
    }

    for (final e in porConvidador.entries) {
      for (final v in e.value) {
        registrarRotulo(v.nome);
      }
    }

    final keys = porConvidador.keys.toSet();
    final somenteRamificacao = _chavesIndicadoresSomenteSubarvoreListaLateral(
      votantes,
      keys,
      apoiadorIdParaNome,
    );
    var prioritarias = keys.difference(somenteRamificacao);
    // Se toda rede encadeia em indicadores já listados como pai, volta a mostrar todas.
    if (prioritarias.isEmpty && keys.isNotEmpty) {
      prioritarias = Set<String>.from(keys);
    }

    /// Quem foi convidado com link/QR de um perfil (indicador ainda aparece assim no cadastro).
    final indicadosPorConviteProfileId = <String, List<Votante>>{};
    for (final w in votantes) {
      final pid = w.convitePorProfileId?.trim();
      if (pid == null || pid.isEmpty) continue;
      indicadosPorConviteProfileId.putIfAbsent(pid, () => []).add(w);
    }

    return IndicacoesRede._(
      rotuloPorChaveConvidador: rotulo,
      indicadosPorChaveConvidador: porConvidador,
      chavesPrioritariasRankingLateral: prioritarias,
      indicadosPorConvitePorProfileConvidante: indicadosPorConviteProfileId,
      apoiadorIdParaNome: Map<String, String>.from(apoiadorIdParaNome),
    );
  }

  /// Indica quem aparece só como parte da sub-red de outro indicador (lista da esquerda).
  static Set<String> _chavesIndicadoresSomenteSubarvoreListaLateral(
    List<Votante> votantes,
    Set<String> chavesConvidadoresNaBase,
    Map<String, String> apoiadorIdParaNome,
  ) {
    final esconder = <String>{};
    for (final v in votantes) {
      final nk = normalizarChaveIndicacao(v.nome);
      if (nk.isEmpty || !chavesConvidadoresNaBase.contains(nk)) continue;
      final paiTexto =
          textoIndicacaoResolvidoAmigosGilberto(v, apoiadorIdParaNome);
      final pk = normalizarChaveIndicacao(paiTexto);
      if (pk.isEmpty || pk == nk || !chavesConvidadoresNaBase.contains(pk)) {
        continue;
      }
      esconder.add(nk);
    }
    return esconder;
  }

  IndicacoesRede._({
    required this.rotuloPorChaveConvidador,
    required Map<String, List<Votante>> indicadosPorChaveConvidador,
    required Set<String> chavesPrioritariasRankingLateral,
    required Map<String, List<Votante>> indicadosPorConvitePorProfileConvidante,
    required Map<String, String> apoiadorIdParaNome,
  })  : _indicadosPorChaveConvidador = indicadosPorChaveConvidador,
        _indicadosPorConvitePorProfileConvidante =
            indicadosPorConvitePorProfileConvidante,
        _apoiadorIdParaNome = apoiadorIdParaNome,
        _chavesPrioritariasRankingLateral = chavesPrioritariasRankingLateral;

  /// Rótulos para exibir (forma mais completa vista nos cadastros).
  final Map<String, String> rotuloPorChaveConvidador;

  final Map<String, List<Votante>> _indicadosPorChaveConvidador;

  final Map<String, List<Votante>> _indicadosPorConvitePorProfileConvidante;

  final Map<String, String> _apoiadorIdParaNome;

  /// Chaves exibidas na lista «quem mais indica» — raízes relativas aos dados (evita repetir ramos já sob outro pai).
  final Set<String> _chavesPrioritariasRankingLateral;

  /// Total de nomes distintos que apareceram na coluna Indicação.
  int get totalConvidadoresComIndicacoesRegistradas =>
      _indicadosPorChaveConvidador.length;

  int get quantidadeIndicadoresNaListaPrioritariaRaiz =>
      _chavesPrioritariasRankingLateral.length;

  /// Cópia mutável dos votantes cuja «Indicação» corresponde a [chaveConvidador].
  List<Votante> indicadosDiretosDe(String chaveConvidador) =>
      List<Votante>.from(
          _indicadosPorChaveConvidador[chaveConvidador] ?? const []);

  /// Quem aparece sob **este cadastro** como indicador: mesmos critérios que a lista
  /// («Indicação» normalizada igual ao nome) **mais** quem foi convidado pelo
  /// [`Votante.profileId`] público da pessoa (link/QR), quando esse perfil existe.
  ///
  /// Resolve o caso em que convidados ficam agrupados por `convite_por_nome` «Alana»
  /// e o campo `nome` do cadastro dela está mais completo (ex.: «Alana Maria Silva»).
  List<Votante> indicadosDiretosApartirCadastro(Votante indicador) {
    final vistos = <String>{};
    final candidatos = <Votante>[];

    void adicionar(Iterable<Votante> grupo) {
      for (final w in grupo) {
        if (!vistos.add(w.id)) continue;
        candidatos.add(w);
      }
    }

    final kNome = normalizarChaveIndicacao(indicador.nome);
    adicionar(indicadosDiretosDe(kNome));

    final meuProfile = indicador.profileId?.trim();
    if (meuProfile != null && meuProfile.isNotEmpty) {
      adicionar(
          _indicadosPorConvitePorProfileConvidante[meuProfile] ?? const []);
    }

    /// Evita aparecer sob o nome errado quando a chave colide com texto sem
    /// relação — mas mantém sempre quem veio pelo `convite_por_profile_id`.
    final filtrados = candidatos.where((w) {
      final kPaiDeclarado =
          normalizarChaveIndicacao(textoIndicacaoResolvidoAmigosGilberto(
        w,
        _apoiadorIdParaNome,
      ));
      if (meuProfile != null &&
          meuProfile.isNotEmpty &&
          meuProfile == w.convitePorProfileId?.trim()) {
        return true;
      }
      return kPaiDeclarado == kNome;
    }).toList();

    filtrados
        .sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return filtrados;
  }

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
  ({int pessoasNaRede, int votosNaRede}) alcanceSubarvore(
      String chaveRaizConvidador) {
    final diretos = indicadosDiretosDe(chaveRaizConvidador);

    var pessoas = diretos.length;
    var votos = 0;
    final idsJaProcessadosNestasSubarvoresDoPrimeiroGrau = <String>{};

    for (final v in diretos) {
      votos += v.qtdVotosFamilia;
      final sub = _accumSubarvorePorCadastro(
        v,
        idsJaProcessadosNestasSubarvoresDoPrimeiroGrau,
      );
      pessoas += sub.pessoasNaRede;
      votos += sub.votosNaRede;
    }
    return (pessoasNaRede: pessoas, votosNaRede: votos);
  }

  /// Profundidade a partir de um cadastro (ramos seguintes usando [indicadosDiretosApartirCadastro]).
  ({int pessoasNaRede, int votosNaRede}) _accumSubarvorePorCadastro(
    Votante raizCadastro,
    Set<String> visitadosPorIdVotanteNaSubarvore,
  ) {
    if (!visitadosPorIdVotanteNaSubarvore.add(raizCadastro.id)) {
      return (pessoasNaRede: 0, votosNaRede: 0);
    }

    final filhos = indicadosDiretosApartirCadastro(raizCadastro);
    var pessoas = filhos.length;
    var votos = 0;

    for (final c in filhos) {
      votos += c.qtdVotosFamilia;
      final sub =
          _accumSubarvorePorCadastro(c, visitadosPorIdVotanteNaSubarvore);
      pessoas += sub.pessoasNaRede;
      votos += sub.votosNaRede;
    }
    return (pessoasNaRede: pessoas, votosNaRede: votos);
  }

  List<String> rankingConvidadores({
    String filtroNome = '',
    bool listarTodosIndicadoresDaColuna = false,
  }) {
    final q = normalizarChaveIndicacao(filtroNome);
    final origemKeys = listarTodosIndicadoresDaColuna
        ? _indicadosPorChaveConvidador.keys
        : _chavesPrioritariasRankingLateral;
    final keys = origemKeys.toList();
    keys.sort((a, b) {
      final cmp =
          contagemIndicacaoDireta(b).compareTo(contagemIndicacaoDireta(a));
      if (cmp != 0) return cmp;
      return rotuloExibir(a).compareTo(rotuloExibir(b));
    });
    if (q.isEmpty) return keys;
    return keys
        .where(
            (k) => k.contains(q) || rotuloExibir(k).toUpperCase().contains(q))
        .toList();
  }

  List<Votante> votantesSemIndicacao(List<Votante> todos) {
    return todos.where((v) {
      final c = v.convitePorNome?.trim();
      return c == null || c.isEmpty;
    }).toList();
  }

  List<Votante> votantesComIndicacao(List<Votante> todos) => todos
      .where((v) =>
          v.convitePorNome != null && v.convitePorNome!.trim().isNotEmpty)
      .toList();
}
