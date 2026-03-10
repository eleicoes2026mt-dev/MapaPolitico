import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dashboard/providers/dashboard_provider.dart';

class PerformanceTab extends ConsumerWidget {
  const PerformanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);

    return stats.when(
      data: (s) {
        final meta = 50000.0;
        final cobertura = s.estimativaVotos.toDouble();
        final pct = meta > 0 ? (cobertura / meta * 100) : 0.0;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _Card(label: 'META ESTADUAL', value: '50.000', sub: 'votos alvo'),
                  _Card(label: 'COBERTURA ATUAL', value: '${cobertura.toInt()}', sub: 'votantes + apoiadores', color: Colors.green.shade100),
                  _Card(label: '% DA META', value: '${pct.toStringAsFixed(1)}%', sub: '', color: Colors.purple.shade100),
                  _Card(label: 'CIDADES ALTA PERF.', value: '2', sub: 'enviar reconhecimento →', color: Colors.amber.shade100),
                ],
              ),
              const SizedBox(height: 24),
              Text('Monitoramento por Cidade', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Buscar cidade...', prefixIcon: Icon(Icons.search)))),
                  const SizedBox(width: 12),
                  DropdownButton<String>(value: 'Todos os Polos', items: const [DropdownMenuItem(value: 'Todos os Polos', child: Text('Todos os Polos'))], onChanged: (_) {}),
                  const SizedBox(width: 8),
                  DropdownButton<String>(value: 'Todos Status', items: const [DropdownMenuItem(value: 'Todos Status', child: Text('Todos Status'))], onChanged: (_) {}),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Lista de cidades com performance (dados do dashboard).'),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro: $e'),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.value, required this.sub, this.color});

  final String label;
  final String value;
  final String sub;
  final Color? color;

  /// Cor do texto com bom contraste sobre o fundo do cartão.
  static Color _textColorOnBackground(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.light
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF5F5F5);
  }

  static Color _secondaryTextColorOnBackground(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.light
        ? const Color(0xFF424242)
        : const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final useContrast = color != null;
    final primary = useContrast ? _textColorOnBackground(color!) : null;
    final secondary = useContrast ? _secondaryTextColorOnBackground(color!) : null;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.labelMedium?.copyWith(
                  color: secondary ?? primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: theme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: theme.bodySmall?.copyWith(color: secondary ?? primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
