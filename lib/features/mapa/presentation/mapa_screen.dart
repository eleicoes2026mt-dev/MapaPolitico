import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../../estrategia/providers/regioes_fundidas_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../providers/estimativa_por_cidade_provider.dart';
import 'widgets/mapa_regional_widget.dart';

/// Painel de locais de votação exibido no bloco principal (abaixo do mapa).
class _LocaisVotacaoPanel extends StatelessWidget {
  const _LocaisVotacaoPanel({
    required this.nomeMunicipio,
    required this.onClose,
  });

  final String nomeMunicipio;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final displayNome = displayNomeCidadeMT(nomeMunicipio);
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(locaisVotacaoPorMunicipioProvider(nomeMunicipio));
        final estimativaAsync = ref.watch(estimativaPorCidadeProvider);
        final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
        final votosTseCidade = votosPorMunicipio[nomeMunicipio] ?? 0;
        final estimativaCidade = estimativaAsync.valueOrNull?[normalizarNomeMunicipioMT(nomeMunicipio)] ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.place, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Locais de votação — $displayNome',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            if (estimativaCidade > 0 || votosTseCidade > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Estimativa (campanha): $estimativaCidade  •  Votos 2022 (TSE): $votosTseCidade',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: async.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nenhum local de votação encontrado para esta cidade na base TSE (2022).',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final totalCidade = list.fold<int>(0, (s, e) => s + e.votos);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final loc = list[i];
                      final pct = totalCidade > 0 ? (loc.votos / totalCidade * 100) : 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.location_on_outlined, color: theme.colorScheme.onPrimaryContainer, size: 20),
                          ),
                          title: Text(
                            loc.nome,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (loc.endereco != null && loc.endereco!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    loc.endereco!,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${loc.votos} votos${totalCidade > 0 ? ' (${pct.toStringAsFixed(1)}% do total da cidade)' : ''}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erro ao carregar locais: $e',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MapaScreen extends ConsumerStatefulWidget {
  const MapaScreen({super.key});

  @override
  ConsumerState<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends ConsumerState<MapaScreen> {
  String? _selectedMunicipio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
    final estimativaPorCidade = ref.watch(estimativaPorCidadeProvider).valueOrNull;
    final cidadesComApoiador = ref.watch(cidadesComApoiadorProvider);
    final regioesFundidas = ref.watch(regioesFundidasParaMapaProvider);
    final nomesCustomizados = ref.watch(nomesCustomizadosProvider).valueOrNull ?? {};
    final coresCustomizadas = ref.watch(coresCustomizadasProvider).valueOrNull ?? {};
    final isAdmin = ref.watch(isAdminProvider);
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: MapaRegionalWidget(
                height: double.infinity,
                votosPorMunicipio: votosPorMunicipio.isEmpty ? null : votosPorMunicipio,
                estimativaPorCidade: estimativaPorCidade?.isEmpty ?? true ? null : estimativaPorCidade,
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
                onCityTap: (nome) => setState(() => _selectedMunicipio = nome),
                locaisVotacaoContent: _selectedMunicipio != null
                    ? _LocaisVotacaoPanel(
                        nomeMunicipio: _selectedMunicipio!,
                        onClose: () => setState(() => _selectedMunicipio = null),
                      )
                    : null,
                selectedMunicipioKey: _selectedMunicipio,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            votosPorMunicipio.isEmpty && cidadesComApoiador.isEmpty
                ? 'Mapa interativo MT com regiões e cidades. Selecione seu candidato 2022 em Meu perfil para ver votos por cidade. Cadastre apoiadores para ver cidades no mapa.'
                : 'Mapa com ${votosPorMunicipio.length} cidade(s) com votos (TSE) e ${cidadesComApoiador.length} cidade(s) com apoiadores. Toque numa cidade (mapa ou lista) para ver locais de votação e endereços.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
