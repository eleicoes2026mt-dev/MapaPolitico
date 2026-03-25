import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mapa_regional_panel.dart';

/// Tela dedicada do menu «Mapa» — mesmo painel do Dashboard, em tela cheia.
class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: const MapaRegionalPanel(mode: MapaPanelMode.fullScreen),
      ),
    );
  }
}

