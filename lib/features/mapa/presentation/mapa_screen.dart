import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../../estrategia/providers/regioes_fundidas_provider.dart';
import 'widgets/mapa_regional_widget.dart';

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
    final regioesFundidas = ref.watch(regioesFundidasParaMapaProvider);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final padding = width < 600 ? 16.0 : 24.0;
    final mapHeight = (height * 0.5).clamp(320.0, 560.0);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Mapa Regional',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const EstadoMTBadge(compact: true),
            ],
          ),
          SizedBox(height: padding),
          Card(
            clipBehavior: Clip.antiAlias,
            child: MapaRegionalWidget(
              height: mapHeight,
              votosPorMunicipio: votosPorMunicipio.isEmpty ? null : votosPorMunicipio,
              regioesFundidas: regioesFundidas.isEmpty ? null : regioesFundidas,
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
