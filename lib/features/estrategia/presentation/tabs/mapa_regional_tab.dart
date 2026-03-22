import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../../../core/constants/regioes_mt.dart';
import '../../../mapa/providers/cidades_marcadores_provider.dart';
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

  void _mostrarRegioesMapeadas(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regiões mapeadas'),
        content: SizedBox(
          width: 320,
          child: Consumer(
            builder: (ctx, ref, _) {
              final asyncRegioes = ref.watch(regioesMapeadasMTProvider);
              return asyncRegioes.when(
                data: (regioes) {
                  if (regioes.isEmpty) {
                    return const Text('Nenhuma região carregada.');
                  }
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${regioes.length} regiões do arquivo (GeoJSON), na ordem do mapa:',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        ...regioes.map((r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: r.cor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(r.nome, style: const TextStyle(fontSize: 15))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Erro ao carregar: $e', style: TextStyle(color: theme.colorScheme.error)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
    final cidadesComApoiador = ref.watch(cidadesComApoiadorProvider);
    final regioesFundidas = ref.watch(regioesFundidasParaMapaProvider);
    final nomesCustomizados = ref.watch(nomesCustomizadosProvider).valueOrNull ?? {};
    final coresCustomizadas = ref.watch(coresCustomizadasProvider).valueOrNull ?? {};
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);

    final selecionadas = _selectedCdRgints.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mapa Interativo — Regiões de MT',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'Clique em uma região para editar o nome. Segure Ctrl (ou Cmd) e clique em duas ou mais regiões para fundi-las.'
                          '${votosPorMunicipio.isEmpty && cidadesComApoiador.isEmpty ? '' : ' Marcadores: votos por cidade (TSE) e cidades com apoiadores ou votantes.'}'
                        : 'Mapa das regiões de MT.'
                          '${votosPorMunicipio.isEmpty && cidadesComApoiador.isEmpty ? '' : ' Marcadores: votos por cidade (TSE) e cidades com apoiadores ou votantes.'}',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _mostrarRegioesMapeadas(context),
              icon: const Icon(Icons.list_alt, size: 20),
              label: const Text('Ver regiões mapeadas'),
            ),
          ],
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
                      cidadesComApoiador: cidadesComApoiador.isEmpty ? null : cidadesComApoiador,
                      regioesFundidas: regioesFundidas.isEmpty ? null : regioesFundidas,
                      nomesCustomizados: nomesCustomizados.isEmpty ? null : nomesCustomizados,
                      coresCustomizadas: coresCustomizadas.isEmpty ? null : coresCustomizadas,
                      onSaveNomeRegiao: isAdmin
                          ? (cdRgint, nome) {
                              ref.read(nomesCustomizadosProvider.notifier).setNome(cdRgint, nome);
                            }
                          : null,
                      onRemoverDaFusao: isAdmin
                          ? (cdRgint) {
                              ref.read(regioesFundidasProvider.notifier).removeCdRgintFromFusion(cdRgint);
                            }
                          : null,
                      onSaveCorRegiao: isAdmin
                          ? (cdRgint, hexCor) {
                              ref.read(coresCustomizadasProvider.notifier).setCor(cdRgint, hexCor);
                            }
                          : null,
                      onRegionTap: isAdmin ? _onRegionTap : null,
                    ),
                  if (isAdmin && selecionadas >= 2) ...[
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
