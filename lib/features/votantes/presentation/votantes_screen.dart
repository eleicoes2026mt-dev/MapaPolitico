import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/votante.dart';
import '../providers/votantes_provider.dart';

class VotantesScreen extends ConsumerStatefulWidget {
  const VotantesScreen({super.key});

  @override
  ConsumerState<VotantesScreen> createState() => _VotantesScreenState();
}

class _VotantesScreenState extends ConsumerState<VotantesScreen> {
  String _query = '';
  String _cidadeFilter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(votantesListProvider);
    final votantes = list.valueOrNull ?? [];
    final votosTotal = votantes.fold<int>(0, (a, v) => a + v.qtdVotosFamilia);
    var filtered = votantes;
    if (_query.isNotEmpty) filtered = filtered.where((v) => v.nome.toLowerCase().contains(_query.toLowerCase())).toList();
    if (_cidadeFilter.isNotEmpty) filtered = filtered.where((v) => v.municipioId == _cidadeFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Votantes', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar votante...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Filtrar cidade...', prefixIcon: Icon(Icons.filter_list)),
                  onChanged: (v) => setState(() => _cidadeFilter = v),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Novo Votante')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(label: Text('${filtered.length} votantes')),
              const SizedBox(width: 8),
              Chip(label: Text('$votosTotal votos estimados')),
            ],
          ),
          const SizedBox(height: 16),
          list.when(
            data: (_) => _VotantesTable(votantes: filtered),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    );
  }
}

class _VotantesTable extends StatelessWidget {
  const _VotantesTable({required this.votantes});

  final List<Votante> votantes;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 700;
    if (isNarrow) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: votantes.length,
        itemBuilder: (_, i) {
          final v = votantes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(v.nome),
              subtitle: Text('${v.telefone ?? ""} • ${v.abrangencia} • ${v.qtdVotosFamilia} voto(s)'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
                ],
              ),
            ),
          );
        },
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nome')),
          DataColumn(label: Text('Contato')),
          DataColumn(label: Text('Cidade')),
          DataColumn(label: Text('Abrangência')),
          DataColumn(label: Text('Votos')),
          DataColumn(label: Text('Apoiador')),
          DataColumn(label: Text('Ações')),
        ],
        rows: votantes.map((v) => DataRow(
          cells: [
            DataCell(Text(v.nome)),
            DataCell(Text(v.telefone ?? '—')),
            DataCell(Text(v.municipioId ?? '—')),
            DataCell(Text(v.abrangencia)),
            DataCell(Text('${v.qtdVotosFamilia}')),
            DataCell(const Text('—')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {}),
                IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () {}),
              ],
            )),
          ],
        )).toList(),
      ),
    );
  }
}
