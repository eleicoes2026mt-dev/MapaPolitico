import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/visita.dart';
import '../providers/agenda_provider.dart';

/// Candidato e assessor: resumo no menu (hoje + próximos 5 dias).
bool mostrarAniversariantesNoMenu({required String? role}) =>
    role == 'candidato' || role == 'assessor';

class SidebarAniversariantesBanner extends ConsumerWidget {
  const SidebarAniversariantesBanner({super.key, this.isDrawer = false});

  final bool isDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allAsync = ref.watch(aniversariantesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            context.go('/mensagens?tab=aniversariantes');
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: allAsync.when(
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titulo(theme),
                  const SizedBox(height: 2),
                  Text(
                    'Hoje e próximos 5 dias',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (lista) {
                final hoje = lista.where((a) => a.isHoje).toList();
                final prox5 = lista
                    .where(
                      (a) =>
                          !a.isHoje &&
                          a.diasParaAniversario >= 1 &&
                          a.diasParaAniversario <= 5,
                    )
                    .toList()
                  ..sort((a, b) {
                    final c = a.diasParaAniversario.compareTo(b.diasParaAniversario);
                    if (c != 0) return c;
                    return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
                  });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titulo(theme),
                    const SizedBox(height: 2),
                    Text(
                      'Hoje e próximos 5 dias',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hoje.isEmpty && prox5.isEmpty)
                      Text(
                        'Nenhum aniversário neste período.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      if (hoje.isNotEmpty)
                        _LinhaHoje(
                          theme: theme,
                          nomes: hoje.map((e) => e.nome).toList(),
                        ),
                      if (hoje.isNotEmpty && prox5.isNotEmpty) const SizedBox(height: 8),
                      if (prox5.isNotEmpty) _LinhaProximos(theme: theme, lista: prox5),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.cake_outlined, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Aniversariantes',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline),
      ],
    );
  }
}

class _LinhaHoje extends StatelessWidget {
  const _LinhaHoje({required this.theme, required this.nomes});

  final ThemeData theme;
  final List<String> nomes;

  @override
  Widget build(BuildContext context) {
    final texto = _formatarNomesMenu(nomes);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'HOJE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LinhaProximos extends StatelessWidget {
  const _LinhaProximos({required this.theme, required this.lista});

  final ThemeData theme;
  final List<Aniversariante> lista;

  @override
  Widget build(BuildContext context) {
    final buf = StringBuffer();
    for (var i = 0; i < lista.length && i < 5; i++) {
      final a = lista[i];
      final quando = a.diasParaAniversario == 1
          ? 'em 1 dia'
          : 'em ${a.diasParaAniversario} dias';
      if (i > 0) buf.writeln();
      buf.write('${a.nome} — $quando');
    }
    final extra = lista.length - 5;
    if (extra > 0) {
      buf.writeln();
      buf.write('+ $extra ${extra == 1 ? 'outro' : 'outros'}');
    }
    return Text(
      buf.toString(),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
      maxLines: 9,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _formatarNomesMenu(List<String> nomes) {
  if (nomes.isEmpty) return '';
  if (nomes.length == 1) return nomes.first;
  if (nomes.length == 2) return '${nomes[0]} e ${nomes[1]}';
  final head = nomes.take(3).join(', ');
  final rest = nomes.length - 3;
  return '$head e mais $rest';
}
