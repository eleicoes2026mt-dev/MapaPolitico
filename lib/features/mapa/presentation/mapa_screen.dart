import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import 'widgets/mapa_regional_widget.dart';

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mapa Regional',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: MapaRegionalWidget(
              height: 480,
              votosPorMunicipio: votosPorMunicipio.isEmpty ? null : votosPorMunicipio,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            votosPorMunicipio.isEmpty
                ? 'Mapa interativo MT com 5 Polos. Importe CSV em Dados TSE e selecione seu nome em Meu perfil para ver votos por cidade.'
                : 'Mapa com ${votosPorMunicipio.length} cidade(s) com votos (TSE). Toque nos marcadores para ver quantidade.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
