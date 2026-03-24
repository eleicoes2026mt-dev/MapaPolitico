import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/estado_mt_badge.dart';
import '../../auth/providers/auth_provider.dart' show profileProvider;
import '../../configuracoes/providers/menu_access_provider.dart';
import '../providers/apoiadores_provider.dart' show apoiadoresListProvider;
import '../providers/campanha_kpis_provider.dart';
import 'dialogs/novo_apoiador_dialog.dart';
import 'utils/apoiadores_form_utils.dart';
import 'widgets/apoiador_card.dart';
import 'widgets/apoiadores_campanha_kpis_panel.dart';

/// Lista de apoiadores com busca, filtro por perfil, KPIs (candidato/assessor) e cadastro/edição.
class ApoiadoresScreen extends ConsumerStatefulWidget {
  const ApoiadoresScreen({super.key});

  @override
  ConsumerState<ApoiadoresScreen> createState() => _ApoiadoresScreenState();
}

class _ApoiadoresScreenState extends ConsumerState<ApoiadoresScreen> {
  String _query = '';
  String _perfilFilter = 'Todos os Perfis';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(registerMenuAccessProvider)('apoiadores');
    });
  }

  Future<void> _abrirNovoApoiador() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => NovoApoiadorDialog(
        onCreate: () => ref.invalidate(apoiadoresListProvider),
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

    var filtered = listAsync.valueOrNull ?? [];
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered.where((a) => a.nome.toLowerCase().contains(q)).toList();
    }
    if (_perfilFilter != 'Todos os Perfis') {
      filtered = filtered.where((a) => a.perfil == _perfilFilter).toList();
    }

    return SingleChildScrollView(
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
          const SizedBox(height: 24),
          listAsync.when(
            data: (_) {
              final podeEditar = profile?.role == 'candidato' || profile?.role == 'assessor';
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
                            onRefresh: () => ref.invalidate(apoiadoresListProvider),
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
    );
  }
}
