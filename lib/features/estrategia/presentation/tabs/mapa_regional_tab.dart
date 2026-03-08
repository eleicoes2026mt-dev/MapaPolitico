import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dados_tse/providers/dados_tse_provider.dart';
import '../../../mapa/presentation/widgets/mapa_regional_widget.dart';

class MapaRegionalTab extends ConsumerWidget {
  const MapaRegionalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mapa Interativo — Regiões de MT',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '5 POLOS REGIONAIS — MT. Clique em um polo no mapa para ver detalhes.'
            '${votosPorMunicipio.isEmpty ? '' : ' Marcadores com votos por cidade (TSE).'}',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          MapaRegionalWidget(
            height: 450,
            votosPorMunicipio: votosPorMunicipio.isEmpty ? null : votosPorMunicipio,
          ),
        ],
      ),
    );
  }
}
