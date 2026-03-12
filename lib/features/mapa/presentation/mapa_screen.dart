import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../../estrategia/providers/regioes_fundidas_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../providers/estimativa_por_cidade_provider.dart';
import 'widgets/mapa_regional_widget.dart';

void _showLocaisVotacaoSheet(BuildContext context, WidgetRef ref, String nomeMunicipio) {
  final displayNome = displayNomeCidadeMT(nomeMunicipio);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Consumer(
        builder: (ctx, ref, _) {
          final async = ref.watch(locaisVotacaoPorMunicipioProvider(nomeMunicipio));
          final estimativaAsync = ref.watch(estimativaPorCidadeProvider);
          final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
          final votosTseCidade = votosPorMunicipio[nomeMunicipio] ?? 0;
          final estimativaCidade = estimativaAsync.valueOrNull?[normalizarNomeMunicipioMT(nomeMunicipio)] ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.place, color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Locais de votação — $displayNome',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              if (estimativaCidade > 0 || votosTseCidade > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Estimativa (campanha): $estimativaCidade  •  Votos 2022 (TSE): $votosTseCidade',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: async.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhum local de votação encontrado para esta cidade na base TSE (2022).',
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final totalCidade = list.fold<int>(0, (s, e) => s + e.votos);
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final loc = list[i];
                        final pct = totalCidade > 0 ? (loc.votos / totalCidade * 100) : 0.0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                            ),
                            title: Text(
                              loc.nome,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${loc.votos} votos${totalCidade > 0 ? ' (${pct.toStringAsFixed(1)}% do total da cidade)' : ''}',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              child:                 MapaRegionalWidget(
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
                onCityTap: (nome) => _showLocaisVotacaoSheet(context, ref, nome),
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
