import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/apoiador.dart';
import '../../../models/municipio.dart';
import '../../auth/providers/auth_provider.dart' show profileProvider;
import '../../benfeitorias/providers/benfeitorias_provider.dart' show invalidateBenfeitoriasCaches;
import '../../configuracoes/providers/campanha_audit_provider.dart' show campanhaAuditLogProvider;
import '../../configuracoes/providers/menu_access_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart' show dashboardStatsProvider;
import '../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT, normalizarNomeMunicipioMT;
import '../../mensagens/providers/mensagens_provider.dart' show polosRegioesListProvider;
import '../../votantes/providers/votantes_provider.dart' show municipiosMTListProvider;
import '../providers/apoiadores_provider.dart' show apoiadoresListProvider;
import '../providers/campanha_kpis_provider.dart';
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

enum _ApoiadoresViewMode { grid, ranking }

/// Lista de apoiadores com busca, filtro por perfil, KPIs (candidato/assessor) e cadastro/edição.
class ApoiadoresScreen extends ConsumerStatefulWidget {
  const ApoiadoresScreen({super.key});

  @override
  ConsumerState<ApoiadoresScreen> createState() => _ApoiadoresScreenState();
}

class _ApoiadoresScreenState extends ConsumerState<ApoiadoresScreen> {
  String _query = '';
  String _perfilFilter = 'Todos os Perfis';
  _ApoiadoresViewMode _viewMode = _ApoiadoresViewMode.grid;
  String? _cidadeChaveFiltro;
  String? _poloIdFiltro;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final ehApoiador = profile?.role == 'apoiador';
    final mostrarKpis = profile?.role == 'candidato' || profile?.role == 'assessor';

    final listAsync = ref.watch(apoiadoresListProvider);
    final munList = ref.watch(municipiosMTListProvider).valueOrNull ?? [];
    final polos = ref.watch(polosRegioesListProvider).valueOrNull ?? [];

    var filtered = List<Apoiador>.from(listAsync.valueOrNull ?? []);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered.where((a) => a.nome.toLowerCase().contains(q)).toList();
    }
    if (_perfilFilter != 'Todos os Perfis') {
      filtered = filtered.where((a) => a.perfil == _perfilFilter).toList();
    }

    final aposBuscaPerfil = List<Apoiador>.from(filtered);

    final cidadeOpcoes = <String, String>{};
    for (final a in aposBuscaPerfil) {
      final ch = _cidadeChave(a, munList);
      if (ch != null) cidadeOpcoes[ch] = _cidadeLabel(a, munList);
    }
    final cidadesSorted = cidadeOpcoes.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final cidadeDropdownValue = _cidadeChaveFiltro != null &&
            cidadesSorted.any((e) => e.key == _cidadeChaveFiltro)
        ? _cidadeChaveFiltro
        : null;
    final poloDropdownValue =
        _poloIdFiltro != null && polos.any((p) => p.id == _poloIdFiltro) ? _poloIdFiltro : null;

    filtered = aposBuscaPerfil;
    if (cidadeDropdownValue != null) {
      filtered = filtered.where((a) => _cidadeChave(a, munList) == cidadeDropdownValue).toList();
    }
    if (poloDropdownValue != null) {
      filtered = filtered.where((a) => _poloIdParaApoiador(a, munList) == poloDropdownValue).toList();
    }

    if (_viewMode == _ApoiadoresViewMode.ranking) {
      filtered.sort((a, b) {
        final c = b.estimativaVotos.compareTo(a.estimativaVotos);
        if (c != 0) return c;
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });
    } else {
      filtered.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshApoiadoresCampanha();
        ref.invalidate(municipiosMTListProvider);
        ref.invalidate(polosRegioesListProvider);
        await ref.read(apoiadoresListProvider.future).then((_) {}).onError((_, __) {});
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
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const EstadoMTBadge(compact: true),
              ],
            ),
            const SizedBox(height: 16),
            if (mostrarKpis) ...[
              ref.watch(campanhaKpisProvider).when(
                    data: (k) => k == null ? const SizedBox.shrink() : ApoiadoresCampanhaKpisPanel(resumo: k),
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
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _perfilFilter,
                  items: ['Todos os Perfis', ...perfisOpcoesApoiador]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _perfilFilter = v ?? 'Todos os Perfis'),
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
                      value: _ApoiadoresViewMode.grid,
                      label: Text('Grade'),
                      icon: Icon(Icons.grid_view_outlined),
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
                    setState(() => _viewMode = next.first);
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
                              child: Text(e.value, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _cidadeChaveFiltro = v),
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
                              child: Text(p.nome, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _poloIdFiltro = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            listAsync.when(
              data: (_) {
                final podeEditar = profile?.role == 'candidato' || profile?.role == 'assessor';
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
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                if (_viewMode == _ApoiadoresViewMode.ranking) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final rank = index + 1;
                      final a = filtered[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, right: 10),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                '$rank',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ApoiadorCard(
                              apoiador: a,
                              podeEditar: podeEditar,
                              podeRevogarAcesso: podeRevogarAcesso,
                              podeExcluir: podeExcluirApoiador,
                              onRefresh: _refreshApoiadoresCampanha,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
                return LayoutBuilder(
                  builder: (_, __) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: filtered
                          .map(
                            (a) => ApoiadorCard(
                              apoiador: a,
                              podeEditar: podeEditar,
                              podeRevogarAcesso: podeRevogarAcesso,
                              podeExcluir: podeExcluirApoiador,
                              onRefresh: _refreshApoiadoresCampanha,
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SelectableText('Erro ao carregar apoiadores: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
