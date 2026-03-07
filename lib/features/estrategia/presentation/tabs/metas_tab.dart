import 'package:flutter/material.dart';

class MetasTab extends StatefulWidget {
  const MetasTab({super.key});

  @override
  State<MetasTab> createState() => _MetasTabState();
}

class _MetasTabState extends State<MetasTab> {
  double cuiaba = 30, rondonopolis = 18, sinop = 25, barra = 15, caceres = 12;
  static const metaEstadual = 50000;

  double get total => cuiaba + rondonopolis + sinop + barra + caceres;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Distribuição por Polo (%)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _SliderRow(label: 'Polo Cuiabá', value: cuiaba, onChanged: (v) => setState(() => cuiaba = v)),
          _SliderRow(label: 'Polo Rondonópolis', value: rondonopolis, onChanged: (v) => setState(() => rondonopolis = v)),
          _SliderRow(label: 'Polo Sinop', value: sinop, onChanged: (v) => setState(() => sinop = v)),
          _SliderRow(label: 'Polo Barra do Garças', value: barra, onChanged: (v) => setState(() => barra = v)),
          _SliderRow(label: 'Polo Cáceres', value: caceres, onChanged: (v) => setState(() => caceres = v)),
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
