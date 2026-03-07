import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/apoiador.dart';
import '../providers/apoiadores_provider.dart';

class ApoiadoresScreen extends ConsumerStatefulWidget {
  const ApoiadoresScreen({super.key});

  @override
  ConsumerState<ApoiadoresScreen> createState() => _ApoiadoresScreenState();
}

class _ApoiadoresScreenState extends ConsumerState<ApoiadoresScreen> {
  String _query = '';
  String _perfilFilter = 'Todos os Perfis';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(apoiadoresListProvider);
    var filtered = list.valueOrNull ?? [];
    if (_query.isNotEmpty) {
      filtered = filtered.where((a) => a.nome.toLowerCase().contains(_query.toLowerCase())).toList();
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
              Text('Apoiadores', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(AppConstants.ufLabel, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar apoiador...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _perfilFilter,
                items: ['Todos os Perfis', 'Prefeitural', 'Vereador(a)', 'Líder Religional', 'Empresarial'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _perfilFilter = v ?? 'Todos os Perfis'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Novo Apoiador')),
            ],
          ),
          const SizedBox(height: 24),
          list.when(
            data: (_) => LayoutBuilder(
              builder: (_, c) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filtered.map((a) => _ApoiadorCard(apoiador: a)).toList(),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    );
  }
}

class _ApoiadorCard extends StatelessWidget {
  const _ApoiadorCard({required this.apoiador});

  final Apoiador apoiador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width > 800 ? 380.0 : double.infinity;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: apoiador.isPJ ? Colors.purple.shade100 : Colors.green.shade100,
                    child: apoiador.isPJ
                        ? Icon(Icons.business, color: Colors.purple.shade700)
                        : Text(apoiador.initial, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(apoiador.nome, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (apoiador.perfil != null)
                          Chip(
                            label: Text(apoiador.perfil!, style: theme.textTheme.labelSmall),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (apoiador.telefone != null) ...[
                const SizedBox(height: 8),
                Row(children: [Icon(Icons.phone, size: 18, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 8), Text(apoiador.telefone!, style: theme.textTheme.bodySmall)]),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.people, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('~${apoiador.estimativaVotos} votos estimados', style: theme.textTheme.bodySmall),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
