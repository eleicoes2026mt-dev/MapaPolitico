import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../providers/regioes_fundidas_provider.dart';
import '../../widgets/edit_regiao_nome_dialog.dart';

class MetasTab extends ConsumerStatefulWidget {
  const MetasTab({super.key});

  @override
  ConsumerState<MetasTab> createState() => _MetasTabState();
}

class _MetasTabState extends ConsumerState<MetasTab> {
  static const metaEstadual = 50000;
  final Map<String, double> _percentuaisPorRegiao = {};

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
    final isAdmin = ref.watch(isAdminProvider);
    if (efetivas.isNotEmpty && _percentuaisPorRegiao.length != efetivas.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final defaultPct = 100.0 / efetivas.length;
        for (final r in efetivas) {
          if (!_percentuaisPorRegiao.containsKey(r.id)) {
            _percentuaisPorRegiao[r.id] = defaultPct;
          }
        }
        setState(() {});
      });
    }
    final total = _total(efetivas, _percentuaisPorRegiao);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 4),
          Text(
            'Regiões de MT. Ajuste o percentual de votos por região.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ...efetivas.map((r) {
            final value = _percentuaisPorRegiao[r.id] ?? (efetivas.isEmpty ? 0.0 : 100 / efetivas.length);
            return _SliderRow(
              regiao: r,
              value: value,
              onChanged: (v) => setState(() => _percentuaisPorRegiao[r.id] = v),
              onEditNome: isAdmin
                  ? () async {
                      final ok = await showEditRegiaoNomeDialog(context, ref, r);
                      if (ok && mounted) setState(() {});
                    }
                  : null,
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
  const _SliderRow({
    required this.regiao,
    required this.value,
    required this.onChanged,
    this.onEditNome,
  });

  final RegiaoEfetiva regiao;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback? onEditNome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: InkWell(
              onTap: onEditNome,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Região ${regiao.nome}',
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onEditNome != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
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
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
