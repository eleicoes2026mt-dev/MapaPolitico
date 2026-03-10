import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../../../core/constants/regioes_mt.dart';
import '../../../dados_tse/providers/dados_tse_provider.dart';
import '../../../mapa/presentation/widgets/mapa_regional_widget.dart';
import '../../providers/regioes_fundidas_provider.dart';

class MapaRegionalTab extends ConsumerStatefulWidget {
  const MapaRegionalTab({super.key});

  @override
  ConsumerState<MapaRegionalTab> createState() => _MapaRegionalTabState();
}

class _MapaRegionalTabState extends ConsumerState<MapaRegionalTab> {
  final Set<String> _selectedCdRgints = {};
  final _nomeFusaoController = TextEditingController();

  @override
  void dispose() {
    _nomeFusaoController.dispose();
    super.dispose();
  }

  bool _onRegionTap(String id, String nome, String? cdRgint) {
    if (!HardwareKeyboard.instance.isControlPressed && !HardwareKeyboard.instance.isMetaPressed) return false;
    if (cdRgint == null || cdRgint.isEmpty) return true;
    final fundidas = ref.read(regioesFundidasParaMapaProvider);
    final covered = <String>{};
    for (final f in fundidas) {
      for (final i in f.ids) covered.add(i);
    }
    if (covered.contains(cdRgint)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta região já está em uma fusão. Remova a fusão na aba Regiões para selecioná-la.')),
        );
      }
      return true;
    }
    setState(() {
      if (_selectedCdRgints.contains(cdRgint)) {
        _selectedCdRgints.remove(cdRgint);
      } else {
        _selectedCdRgints.add(cdRgint);
      }
    });
    return true;
  }

  Future<void> _fundirSelecionadas() async {
    if (_selectedCdRgints.length < 2) return;
    final nome = _nomeFusaoController.text.trim();
    if (nome.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um nome para a fusão.')));
      }
      return;
    }
    final ids = _selectedCdRgints.toList()..sort();
    final fundida = RegiaoFundida(id: 'merge_${ids.join("_")}', nome: nome, ids: ids);
    await ref.read(regioesFundidasProvider.notifier).add(fundida);
    setState(() {
      _selectedCdRgints.clear();
      _nomeFusaoController.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fusão "$nome" criada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
    final regioesFundidas = ref.watch(regioesFundidasParaMapaProvider);
    final nomesCustomizados = ref.watch(nomesCustomizadosProvider).valueOrNull ?? {};
    final theme = Theme.of(context);

    final selecionadas = _selectedCdRgints.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mapa Interativo — Regiões de MT',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Clique em uma região para editar o nome. Segure Ctrl (ou Cmd) e clique em duas ou mais regiões para fundi-las.'
          '${votosPorMunicipio.isEmpty ? '' : ' Marcadores com votos por cidade (TSE).'}',
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapHeight = constraints.maxHeight.clamp(280.0, double.infinity);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  MapaRegionalWidget(
                    height: mapHeight,
                    votosPorMunicipio: votosPorMunicipio.isEmpty ? null : votosPorMunicipio,
                    regioesFundidas: regioesFundidas.isEmpty ? null : regioesFundidas,
                    nomesCustomizados: nomesCustomizados.isEmpty ? null : nomesCustomizados,
                    onSaveNomeRegiao: (cdRgint, nome) {
                      ref.read(nomesCustomizadosProvider.notifier).setNome(cdRgint, nome);
                    },
                    onRegionTap: _onRegionTap,
                  ),
                  if (selecionadas >= 2) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '$selecionadas regiões selecionadas: ${_selectedCdRgints.map((id) => regioesIntermediariasMT.where((r) => r.id == id).firstOrNull?.nome ?? id).join(", ")}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _nomeFusaoController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome da fusão',
                                        hintText: 'Ex.: Centro-Norte',
                                        isDense: true,
                                      ),
                                      textCapitalization: TextCapitalization.words,
                                      onSubmitted: (_) => _fundirSelecionadas(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: _fundirSelecionadas,
                                    child: const Text('Fundir'),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Limpar seleção',
                                    icon: const Icon(Icons.clear_all),
                                    onPressed: () => setState(() {
                                      _selectedCdRgints.clear();
                                      _nomeFusaoController.clear();
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
