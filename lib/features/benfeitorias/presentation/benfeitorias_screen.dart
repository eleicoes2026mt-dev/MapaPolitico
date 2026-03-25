import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/benfeitoria.dart';
import '../providers/benfeitorias_provider.dart';

class BenfeitoriasScreen extends ConsumerStatefulWidget {
  const BenfeitoriasScreen({super.key});

  @override
  ConsumerState<BenfeitoriasScreen> createState() => _BenfeitoriasScreenState();
}

class _BenfeitoriasScreenState extends ConsumerState<BenfeitoriasScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(benfeitoriasListProvider);
    final list = async.valueOrNull ?? [];
    final total = list.fold<double>(0, (a, b) => a + b.valor);
    final filtered = list.where((b) => b.titulo.toLowerCase().contains(_query.toLowerCase())).toList();
    final format = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(benfeitoriasListProvider);
        await ref.read(benfeitoriasListProvider.future).then((_) {}).onError((_, __) {});
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
              Text('Benfeitorias', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar benfeitoria...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Nova Benfeitoria')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Total: ${format.format(total)} - ${list.length} registros', style: theme.textTheme.titleSmall?.copyWith(color: Colors.green.shade800)),
          ),
          const SizedBox(height: 24),
          async.when(
            data: (_) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final b = filtered[i];
                return _BenfeitoriaCard(benfeitoria: b, format: format);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    ),
    );
  }
}

class _BenfeitoriaCard extends StatelessWidget {
  const _BenfeitoriaCard({required this.benfeitoria, required this.format});

  final Benfeitoria benfeitoria;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(benfeitoria.titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(format.format(benfeitoria.valor), style: theme.textTheme.titleSmall?.copyWith(color: Colors.green.shade700)),
                const SizedBox(width: 16),
                if (benfeitoria.dataRealizacao != null) Text(DateFormat('dd/MM/yyyy').format(benfeitoria.dataRealizacao!), style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                Chip(
                  label: Text(benfeitoria.tipo, style: theme.textTheme.labelSmall),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(benfeitoria.status == 'concluida' ? 'concluída' : 'em andamento', style: theme.textTheme.labelSmall),
                  backgroundColor: benfeitoria.isConcluida ? Colors.green.shade100 : Colors.orange.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (benfeitoria.descricao != null && benfeitoria.descricao!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(benfeitoria.descricao!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

