import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/apoiador.dart';
import '../../../models/municipio.dart';
import '../../auth/providers/auth_provider.dart' show profileProvider;
import '../../benfeitorias/providers/benfeitorias_provider.dart'
    show invalidateBenfeitoriasCaches;
import '../../configuracoes/providers/campanha_audit_provider.dart'
    show campanhaAuditLogProvider;
import '../../configuracoes/providers/menu_access_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart'
    show dashboardStatsProvider;
import '../../mapa/data/mt_municipios_coords.dart'
    show displayNomeCidadeMT, normalizarNomeMunicipioMT;
import '../../mensagens/providers/mensagens_provider.dart'
    show polosRegioesListProvider;
import '../../votantes/providers/votantes_provider.dart'
    show municipiosMTListProvider;
import '../providers/apoiadores_provider.dart' show apoiadoresListProvider;
import '../providers/campanha_kpis_provider.dart';
import 'dialogs/edicao_lote_apoiadores_dialog.dart';
import 'dialogs/novo_apoiador_dialog.dart';
import 'utils/apoiadores_form_utils.dart';
import 'widgets/apoiador_card.dart';
import 'widgets/apoiadores_campanha_kpis_panel.dart';

/// Polo regional (tabela `municipios.polo_id` → `polos_regioes`) para filtro.
String? _poloIdParaApoiador(Apoiador a, List<Municipio> munList) {
  if (a.municipioId != null && a.municipioId!.isNotEmpty) {
    for (final m in munList) {
      if (m.id == a.municipioId) return m.poloId;
    }
  }
  final raw = a.cidadeNome?.trim();
  if (raw == null || raw.isEmpty) return null;
  final key = normalizarNomeMunicipioMT(raw);
  for (final m in munList) {
    if (normalizarNomeMunicipioMT(m.nome) == key) return m.poloId;
  }
  return null;
}

/// Chave única da cidade para filtro (nome normalizado MT).
String? _cidadeChave(Apoiador a, List<Municipio> munList) {
  if (a.cidadeNome != null && a.cidadeNome!.trim().isNotEmpty) {
    return normalizarNomeMunicipioMT(a.cidadeNome!.trim());
  }
  if (a.municipioId != null) {
    for (final m in munList) {
      if (m.id == a.municipioId) return normalizarNomeMunicipioMT(m.nome);
    }
  }
  return null;
}

String _cidadeLabel(Apoiador a, List<Municipio> munList) {
  if (a.cidadeNome != null && a.cidadeNome!.trim().isNotEmpty) {
    return displayNomeCidadeMT(a.cidadeNome!.trim());
  }
  if (a.municipioId != null) {
    for (final m in munList) {
      if (m.id == a.municipioId) return displayNomeCidadeMT(m.nome);
    }
  }
  return '—';
}

/// Chave única para filtro de procedência (FK ou nome legado).
String? _origemChave(Apoiador a) {
  final id = a.origemLugarId?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';
  final n = a.origemLugarNome?.trim();
  if (n != null && n.isNotEmpty) return 'nome:${n.toLowerCase()}';
  return null;
}

bool _apoiadorMatchOrigemFiltro(Apoiador a, String chave) {
  if (chave.startsWith('id:')) {
    return a.origemLugarId?.trim() == chave.substring(3);
  }
  if (chave.startsWith('nome:')) {
    return a.origemLugarNome?.trim().toLowerCase() == chave.substring(5);
  }
  return false;
}

enum _ApoiadoresViewMode { lista, ranking }

const int _kApoiadoresPageSize = 20;

/// Valor do filtro «todas» (classificação).
const String _kTodasClassificacoes = 'Todas as classificações';

/// Lista de apoiadores com busca, filtro por perfil, KPIs (candidato/assessor) e cadastro/edição.
class ApoiadoresScreen extends ConsumerStatefulWidget {
  const ApoiadoresScreen({super.key});

  @override
  ConsumerState<ApoiadoresScreen> createState() => _ApoiadoresScreenState();
}

class _ApoiadoresScreenState extends ConsumerState<ApoiadoresScreen> {
  String _query = '';
  String _perfilFilter = _kTodasClassificacoes;
  _ApoiadoresViewMode _viewMode = _ApoiadoresViewMode.lista;
  String? _cidadeChaveFiltro;
  String? _poloIdFiltro;
  /// Chave estável para filtro de procedência: `id:<uuid>` ou `nome:<normalizado>`.
  String? _origemChaveFiltro;
  int _pageIndex = 0;

  /// Modo seleção para edição em lote (candidato/assessor).
  bool _modoSelecao = false;
  final Set<String> _idsSelecionados = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(registerMenuAccessProvider)('apoiadores');
    });
  }

  void _refreshApoiadoresCampanha() {
    ref.invalidate(apoiadoresListProvider);
    ref.invalidate(campanhaAuditLogProvider);
    ref.invalidate(dashboardStatsProvider);
    invalidateBenfeitoriasCaches(ref);
  }

  Future<void> _abrirNovoApoiador() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => NovoApoiadorDialog(
        onCreate: _refreshApoiadoresCampanha,
      ),
    );
  }

  void _limparSelecao() {
    _idsSelecionados.clear();
  }

  Future<void> _abrirEdicaoLote(List<String> classificacoesSugestoes) async {
    if (_idsSelecionados.isEmpty) return;
    final ids = _idsSelecionados.toList();
    await showDialog<void>(
      context: context,
      builder: (ctx) => EdicaoLoteApoiadoresDialog(
        apoiadorIds: ids,
        classificacoesSugestoes: classificacoesSugestoes,
        onSaved: () {
          _refreshApoiadoresCampanha();
          if (!mounted) return;
          setState(() {
            _limparSelecao();
            _modoSelecao = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ids.length == 1
                    ? '1 apoiador atualizado.'
                    : '${ids.length} apoiadores atualizados.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _syncPageIfNeeded(int totalFiltered) {
    if (totalFiltered <= 0) return;
    final tp =
        (totalFiltered + _kApoiadoresPageSize - 1) ~/ _kApoiadoresPageSize;
    final maxP = tp - 1;
    final clamped = _pageIndex.clamp(0, maxP);
    if (clamped != _pageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pageIndex = clamped);
      });
    }
  }

  Widget _buildPaginationBar(
    ThemeData theme,
    int total,
    int page,
    int totalPages,
  ) {
    final from = page * _kApoiadoresPageSize + 1;
    final to = min((page + 1) * _kApoiadoresPageSize, total);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            'Mostrando $from–$to de $total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Página anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 0
                ? () => setState(() => _pageIndex = page - 1)
                : null,
          ),
          Text('Página ${page + 1} de $totalPages'),
          IconButton(
            tooltip: 'Próxima página',
            icon: const Icon(Icons.chevron_right),
            onPressed: page < totalPages - 1
                ? () => setState(() => _pageIndex = page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final ehApoiador = profile?.role == 'apoiador';
    final podeEditarLote =
        profile?.role == 'candidato' || profile?.role == 'assessor';
    final mostrarKpis =
        profile?.role == 'candidato' || profile?.role == 'assessor';

    final listAsync = ref.watch(apoiadoresListProvider);
    final munList = ref.watch(municipiosMTListProvider).valueOrNull ?? [];
    final polos = ref.watch(polosRegioesListProvider).valueOrNull ?? [];

    final fullList = listAsync.valueOrNull ?? [];
    final classificacaoOpcoes = <String>[
      _kTodasClassificacoes,
      ...classificacoesSugestoesApoiador(fullList),
    ];
    final perfilEfetivo =
        classificacaoOpcoes.contains(_perfilFilter) ? _perfilFilter : _kTodasClassificacoes;

    var filtered = List<Apoiador>.from(fullList);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered =
          filtered.where((a) => a.nome.toLowerCase().contains(q)).toList();
    }
    if (perfilEfetivo != _kTodasClassificacoes) {
      filtered = filtered.where((a) => a.perfil == perfilEfetivo).toList();
    }

    final aposBuscaPerfil = List<Apoiador>.from(filtered);

    final cidadeOpcoes = <String, String>{};
    for (final a in aposBuscaPerfil) {
      final ch = _cidadeChave(a, munList);
      if (ch != null) cidadeOpcoes[ch] = _cidadeLabel(a, munList);
    }
    final cidadesSorted = cidadeOpcoes.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final origemOpcoes = <String, String>{};
    for (final a in aposBuscaPerfil) {
      final ch = _origemChave(a);
      if (ch != null) {
        final nome = a.origemLugarNome?.trim();
        origemOpcoes[ch] =
            (nome != null && nome.isNotEmpty) ? nome : '—';
      }
    }
    final origensSorted = origemOpcoes.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final cidadeDropdownValue = _cidadeChaveFiltro != null &&
            cidadesSorted.any((e) => e.key == _cidadeChaveFiltro)
        ? _cidadeChaveFiltro
        : null;
    final poloDropdownValue =
        _poloIdFiltro != null && polos.any((p) => p.id == _poloIdFiltro)
            ? _poloIdFiltro
            : null;
    final origemDropdownValue = _origemChaveFiltro != null &&
            origensSorted.any((e) => e.key == _origemChaveFiltro)
        ? _origemChaveFiltro
        : null;

    filtered = aposBuscaPerfil;
    if (cidadeDropdownValue != null) {
      filtered = filtered
          .where((a) => _cidadeChave(a, munList) == cidadeDropdownValue)
          .toList();
    }
    if (poloDropdownValue != null) {
      filtered = filtered
          .where((a) => _poloIdParaApoiador(a, munList) == poloDropdownValue)
          .toList();
    }
    if (origemDropdownValue != null) {
      filtered = filtered
          .where((a) => _apoiadorMatchOrigemFiltro(a, origemDropdownValue))
          .toList();
    }

    if (_viewMode == _ApoiadoresViewMode.ranking) {
      filtered.sort((a, b) {
        final c = b.estimativaVotos.compareTo(a.estimativaVotos);
        if (c != 0) return c;
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });
    } else {
      filtered
          .sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshApoiadoresCampanha();
        ref.invalidate(municipiosMTListProvider);
        ref.invalidate(polosRegioesListProvider);
        await ref
            .read(apoiadoresListProvider.future)
            .then((_) {})
            .onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Apoiadores',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const EstadoMTBadge(compact: true),
              ],
            ),
            const SizedBox(height: 16),
            if (mostrarKpis) ...[
              ref.watch(campanhaKpisProvider).when(
                    data: (k) => k == null
                        ? const SizedBox.shrink()
                        : ApoiadoresCampanhaKpisPanel(resumo: k),
                    loading: () => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'KPIs: $e',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar apoiador...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() {
                      _query = v;
                      _pageIndex = 0;
                      _limparSelecao();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: perfilEfetivo,
                  items: classificacaoOpcoes
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _perfilFilter = v ?? _kTodasClassificacoes;
                    _pageIndex = 0;
                    _limparSelecao();
                  }),
                ),
                const SizedBox(width: 12),
                if (!ehApoiador)
                  FilledButton.icon(
                    onPressed: _abrirNovoApoiador,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Apoiador'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_ApoiadoresViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _ApoiadoresViewMode.lista,
                      label: Text('Lista'),
                      icon: Icon(Icons.view_list_outlined),
                    ),
                    ButtonSegment(
                      value: _ApoiadoresViewMode.ranking,
                      label: Text('Ranking'),
                      icon: Icon(Icons.format_list_numbered_rtl),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (Set<_ApoiadoresViewMode> next) {
                    if (next.isEmpty) return;
                    setState(() {
                      _viewMode = next.first;
                      _pageIndex = 0;
                      _limparSelecao();
                    });
                  },
                ),
                SizedBox(
                  width: 240,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: cidadeDropdownValue,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas as cidades'),
                          ),
                          ...cidadesSorted.map(
                            (e) => DropdownMenuItem<String?>(
                              value: e.key,
                              child: Text(e.value,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _cidadeChaveFiltro = v;
                          _pageIndex = 0;
                          _limparSelecao();
                        }),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Região (polo)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: poloDropdownValue,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas as regiões'),
                          ),
                          ...polos.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child:
                                  Text(p.nome, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _poloIdFiltro = v;
                          _pageIndex = 0;
                          _limparSelecao();
                        }),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Procedência',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: origemDropdownValue,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas as procedências'),
                          ),
                          ...origensSorted.map(
                            (e) => DropdownMenuItem<String?>(
                              value: e.key,
                              child: Text(e.value,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _origemChaveFiltro = v;
                          _pageIndex = 0;
                          _limparSelecao();
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (podeEditarLote) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    avatar: Icon(
                      _modoSelecao
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    label: const Text('Seleção'),
                    selected: _modoSelecao,
                    onSelected: (v) => setState(() {
                      _modoSelecao = v;
                      if (!v) _limparSelecao();
                    }),
                  ),
                  if (_modoSelecao) ...[
                    TextButton(
                      onPressed: () => setState(() {
                        _idsSelecionados
                          ..clear()
                          ..addAll(filtered.map((a) => a.id));
                      }),
                      child: Text('Selecionar todos (${filtered.length})'),
                    ),
                    TextButton(
                      onPressed: () => setState(_limparSelecao),
                      child: const Text('Limpar seleção'),
                    ),
                    if (_idsSelecionados.isNotEmpty)
                      FilledButton.tonalIcon(
                        onPressed: () => _abrirEdicaoLote(
                          classificacoesSugestoesApoiador(fullList),
                        ),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: Text(
                          'Editar em lote (${_idsSelecionados.length})',
                        ),
                      ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 24),
            listAsync.when(
              data: (_) {
                final podeEditar =
                    profile?.role == 'candidato' || profile?.role == 'assessor';
                final podeRevogarAcesso = profile?.role == 'candidato';
                final podeExcluirApoiador = profile?.role == 'candidato';
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        listAsync.valueOrNull?.isEmpty == true
                            ? 'Nenhum apoiador cadastrado ainda.'
                            : 'Nenhum resultado para o filtro atual.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                final total = filtered.length;
                _syncPageIfNeeded(total);
                final totalPages =
                    (total + _kApoiadoresPageSize - 1) ~/ _kApoiadoresPageSize;
                final page = _pageIndex.clamp(0, totalPages - 1);
                final start = page * _kApoiadoresPageSize;
                final pageItems = filtered
                    .skip(start)
                    .take(_kApoiadoresPageSize)
                    .toList();

                if (_viewMode == _ApoiadoresViewMode.ranking) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...List.generate(pageItems.length, (index) {
                        final rank = start + index + 1;
                        final a = pageItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (podeEditarLote && _modoSelecao)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, right: 4),
                                  child: Checkbox(
                                    value: _idsSelecionados.contains(a.id),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _idsSelecionados.add(a.id);
                                      } else {
                                        _idsSelecionados.remove(a.id);
                                      }
                                    }),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 8),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    '$rank',
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme
                                          .colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ApoiadorCard(
                                  apoiador: a,
                                  compact: true,
                                  podeEditar: podeEditar,
                                  podeRevogarAcesso: podeRevogarAcesso,
                                  podeExcluir: podeExcluirApoiador,
                                  onRefresh: _refreshApoiadoresCampanha,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      _buildPaginationBar(theme, total, page, totalPages),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...pageItems.map(
                      (a) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (podeEditarLote && _modoSelecao)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Checkbox(
                                value: _idsSelecionados.contains(a.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _idsSelecionados.add(a.id);
                                  } else {
                                    _idsSelecionados.remove(a.id);
                                  }
                                }),
                              ),
                            ),
                          Expanded(
                            child: ApoiadorCard(
                              apoiador: a,
                              compact: true,
                              podeEditar: podeEditar,
                              podeRevogarAcesso: podeRevogarAcesso,
                              podeExcluir: podeExcluirApoiador,
                              onRefresh: _refreshApoiadoresCampanha,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPaginationBar(theme, total, page, totalPages),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  SelectableText('Erro ao carregar apoiadores: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
