import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/mt_municipios_coords.dart';
import '../../providers/benfeitorias_municipio_mapa_provider.dart';

/// Painel inferior no modo Benfeitorias: lista registros com beneficiário (título) e dados do apoiador.
class BenfeitoriasMunicipioPanel extends ConsumerWidget {
  const BenfeitoriasMunicipioPanel({
    super.key,
    required this.municipioChaveOuNome,
    required this.onClose,
  });

  /// Chave normalizada (lista) ou nome — [benfeitoriasPorMunicipioMapaProvider] normaliza.
  final String municipioChaveOuNome;
  final VoidCallback onClose;

  static String _statusPt(String s) {
    switch (s) {
      case 'concluida':
        return 'Concluída';
      case 'em_andamento':
        return 'Em andamento';
      case 'planejada':
        return 'Planejada';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayNome = displayNomeCidadeMT(normalizarNomeMunicipioMT(municipioChaveOuNome));
    final async = ref.watch(benfeitoriasPorMunicipioMapaProvider(municipioChaveOuNome));
    final curFmt = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final dataFmt = DateFormat('dd/MM/yyyy');

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Icon(Icons.volunteer_activism_outlined, color: theme.colorScheme.tertiary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Benfeitorias — $displayNome',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Fechar',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Cada registo mostra o que foi feito (título) e o apoiador da campanha vinculado ao cadastro.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: async.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma benfeitoria encontrada para este município no cadastro.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final soma = list.fold<double>(0, (s, e) => s + e.benfeitoria.valor);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'Total: ${curFmt.format(soma)} · ${list.length} registo(s)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final item = list[i];
                        final b = item.benfeitoria;
                        final dr = b.dataRealizacao;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.titulo,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      label: Text(b.tipo, style: theme.textTheme.labelSmall),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text(
                                      curFmt.format(b.valor),
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      _statusPt(b.status),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (dr != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Data: ${dataFmt.format(dr)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                                if (b.descricao != null && b.descricao!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    b.descricao!.trim(),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                const Divider(height: 20),
                                Text(
                                  'Apoiador (cadastro na campanha)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.apoiadorNome,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (item.apoiadorTipo != null && item.apoiadorTipo!.isNotEmpty)
                                  Text(
                                    item.apoiadorTipo == 'PJ' ? 'Pessoa jurídica' : 'Pessoa física',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                if (item.apoiadorCidadeNome != null && item.apoiadorCidadeNome!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_city_outlined, size: 14, color: theme.colorScheme.outline),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            displayNomeCidadeMT(normalizarNomeMunicipioMT(item.apoiadorCidadeNome!)),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (item.apoiadorTelefone != null && item.apoiadorTelefone!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.outline),
                                        const SizedBox(width: 4),
                                        Text(item.apoiadorTelefone!, style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                if (item.apoiadorEmail != null && item.apoiadorEmail!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.outline),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.apoiadorEmail!,
                                            style: theme.textTheme.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar benfeitorias: $e',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
