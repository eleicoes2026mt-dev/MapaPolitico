import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../providers/regioes_fundidas_provider.dart';

class MetasTab extends ConsumerStatefulWidget {
  const MetasTab({super.key});

  @override
  ConsumerState<MetasTab> createState() => _MetasTabState();
}

class _MetasTabState extends ConsumerState<MetasTab> {
  static const metaEstadual = 50000;
  final Map<String, double> _percentuaisPorRegiao = {
    '5101': 30,
    '5102': 12,
    '5103': 25,
    '5104': 15,
    '5105': 18,
  };

  double _total(List<RegiaoEfetiva> efetivas, Map<String, double> percentuais) {
    double t = 0;
    for (final r in efetivas) {
      t += percentuais[r.id] ?? (100 / efetivas.length);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final efetivas = ref.watch(regioesEfetivasProvider);
    final total = _total(efetivas, _percentuaisPorRegiao);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editor de Metas Estratégicas', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Text('Meta Estadual de Votos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  decoration: const InputDecoration(isDense: true),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: '$metaEstadual'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('votos totais em MT'),
            ],
          ),
          const SizedBox(height: 24),
          Text('Distribuição por Região (%)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...efetivas.map((r) {
            final value = _percentuaisPorRegiao[r.id] ?? (efetivas.isEmpty ? 0.0 : 100 / efetivas.length);
            return _SliderRow(
              label: 'Região ${r.nome}',
              value: value,
              onChanged: (v) => setState(() => _percentuaisPorRegiao[r.id] = v),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Total: ${total.toStringAsFixed(1)}%', style: theme.textTheme.titleSmall),
              if (total > 100) Text(' (ultrapassou 100%)', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('Salvar Meta Estratégica'),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${value.toStringAsFixed(1)}%',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('${value.toStringAsFixed(1)}%'),
          ),
        ],
      ),
    );
  }
}
