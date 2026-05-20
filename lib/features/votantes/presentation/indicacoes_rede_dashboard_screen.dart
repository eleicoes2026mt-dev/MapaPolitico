import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../models/votante.dart';
import '../../apoiadores/presentation/utils/apoiadores_form_utils.dart' show formatTelefoneBrFromDigits;
import '../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT;
import '../domain/indicacoes_rede.dart';
import '../providers/votantes_provider.dart';

/// Painel de rede de indicações (coluna *Indicação* / convite) para $kAmigosGilbertoLabel.
class IndicacoesRedeDashboardScreen extends ConsumerStatefulWidget {
  const IndicacoesRedeDashboardScreen({super.key});

  @override
  ConsumerState<IndicacoesRedeDashboardScreen> createState() => _IndicacoesRedeDashboardScreenState();
}

class _IndicacoesRedeDashboardScreenState extends ConsumerState<IndicacoesRedeDashboardScreen> {
  final _filtroRanking = TextEditingController();
  String _filtro = '';
  String? _convidadorSelecionado;

  @override
  void dispose() {
    _filtroRanking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(votantesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rede de indicações'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(votantesListProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (votantes) {
          final rede = IndicacoesRede.fromVotantes(votantes);
          final rankingKeys = rede.rankingConvidadores(filtroNome: _filtro);

          if (_convidadorSelecionado != null && !rankingKeys.contains(_convidadorSelecionado)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _convidadorSelecionado = null);
            });
          }

          final twoPane = MediaQuery.sizeOf(context).width >= 980;

          final painelRanking = _PainelRanking(
            tema: theme,
            rede: rede,
            votantesTodos: votantes,
            filtroController: _filtroRanking,
            onFiltroSubmitted: (_) => setState(() => _filtro = _filtroRanking.text.trim()),
            onFiltroChanged: (_) {
              final t = _filtroRanking.text.trim();
              setState(() => _filtro = t);
            },
            rankingKeys: rankingKeys,
            rankingBaseTotal: rede.totalConvidadoresComIndicacoesRegistradas,
            selecionado: _convidadorSelecionado,
            onSelecionar: (k) => setState(() => _convidadorSelecionado = k),
          );

          Widget detalheBody() {
            final sel = _convidadorSelecionado ??
                (rankingKeys.isNotEmpty ? rankingKeys.first : null);
            return _PainelDetalhe(tema: theme, rede: rede, chaveConvidador: sel);
          }

          Future<void> onPull() async {
            ref.invalidate(votantesListProvider);
            await ref.read(votantesListProvider.future).then((_) {}).onError((_, __) {});
          }

          if (twoPane) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 392,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: painelRanking,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: onPull,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: detalheBody(),
                    ),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: onPull,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                painelRanking,
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: detalheBody(),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/votantes'),
        icon: const Icon(Icons.checklist_rounded),
        label: Text(kAmigosGilbertoLabel),
      ),
    );
  }
}

class _PainelRanking extends StatelessWidget {
  const _PainelRanking({
    required this.tema,
    required this.rede,
    required this.votantesTodos,
    required this.filtroController,
    required this.onFiltroChanged,
    required this.onFiltroSubmitted,
    required this.rankingKeys,
    required this.rankingBaseTotal,
    required this.selecionado,
    required this.onSelecionar,
  });

  final ThemeData tema;
  final IndicacoesRede rede;
  final List<Votante> votantesTodos;
  final TextEditingController filtroController;
  final void Function(String) onFiltroChanged;
  final void Function(String) onFiltroSubmitted;
  final List<String> rankingKeys;
  final int rankingBaseTotal;
  final String? selecionado;
  final void Function(String?) onSelecionar;

  @override
  Widget build(BuildContext context) {
    final comInd = rede.votantesComIndicacao(votantesTodos);
    final semInd = rede.votantesSemIndicacao(votantesTodos);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$kAmigosGilbertoLabel — quem mais indica?',
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Baseado na coluna «Indicação»: cada nível seguinte conta quem aquele cadastro indicou usando o próprio nome dele.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.people_outline, label: '${votantesTodos.length} cadastrados'),
              _StatChip(
                icon: Icons.person_search_outlined,
                label: rankingKeys.length != rankingBaseTotal
                    ? '$rankingKeys.length no resultado · $rankingBaseTotal na base'
                    : '$rankingBaseTotal nomes únicos como indicação',
              ),
              _StatChip(icon: Icons.share_outlined, label: '${comInd.length} com indicação'),
              _StatChip(icon: Icons.person_off_outlined, label: '${semInd.length} sem indicação'),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: filtroController,
            decoration: InputDecoration(
              hintText: 'Buscar nome do indicador...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: onFiltroChanged,
            onSubmitted: onFiltroSubmitted,
          ),
          const SizedBox(height: 12),
          if (rankingKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  rankingBaseTotal == 0
                      ? 'Ainda não há indicações preenchidas na base.'
                      : 'Nenhum resultado para o filtro.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rankingKeys.length,
              itemBuilder: (_, i) {
                final key = rankingKeys[i];
                final alcance = rede.alcanceSubarvore(key);
                final diretos = rede.contagemIndicacaoDireta(key);
                final votDir = rede.votosIndicacaoDireta(key);
                final ativo = selecionado == key || (selecionado == null && i == 0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: ativo ? tema.colorScheme.primaryContainer.withValues(alpha: 0.45) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      title: Text(
                        rede.rotuloExibir(key),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$diretos cadastro(s) direto • $votDir voto(s) direto • '
                        '${alcance.pessoasNaRede} na rede (${alcance.votosNaRede} votos)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: CircleAvatar(
                        backgroundColor: tema.colorScheme.secondaryContainer,
                        child: Text('$diretos'),
                      ),
                      onTap: () => onSelecionar(key),
                    ),
                  ),
                );
              },
            ),
          if (rankingKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Toque num nome: a árvore abre ao lado ou abaixo — expanda cada ramo para o próximo nível.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _PainelDetalhe extends StatelessWidget {
  const _PainelDetalhe({
    required this.tema,
    required this.rede,
    required this.chaveConvidador,
  });

  final ThemeData tema;
  final IndicacoesRede rede;
  final String? chaveConvidador;

  @override
  Widget build(BuildContext context) {
    if (chaveConvidador == null || chaveConvidador!.isEmpty) {
      return Center(
        child: Text(
          'Selecione um indicador na lista para ver os detalhes.',
          style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    final key = chaveConvidador!;
    final diretos = rede.indicadosDiretosDe(key);
    diretos.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final alcance = rede.alcanceSubarvore(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rede.rotuloExibir(key),
          style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${diretos.length} pessoa(s) no primeiro ramo (${diretos.length == 1 ? 'indicado' : 'indicadas'} diretamente) · '
          '${alcance.pessoasNaRede - diretos.length} nos ramos seguintes · '
          '${alcance.votosNaRede} votos estimados em toda a árvore.',
          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Text(
          'Árvore de indicações',
          style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'O indicador fica na raíz. Cada pessoa aparece apenas no ramo de quem a indicou; '
          'expanda um nome para ver quem ele indicou a seguir.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _ArvoreIndicacaoRaiz(rede: rede, chaveConvidador: key),
      ],
    );
  }
}

String _linhaDetalhesVotante(Votante v) {
  final cid = v.cidadeDisplay.trim().isEmpty ? '—' : displayNomeCidadeMT(v.cidadeDisplay);
  final tel = v.telefone == null || v.telefone!.isEmpty ? '—' : formatTelefoneBrFromDigits(v.telefone);
  return '$tel · $cid · ${v.qtdVotosFamilia} voto(s) · ${v.abrangencia}';
}

class _ArvoreIndicacaoRaiz extends StatelessWidget {
  const _ArvoreIndicacaoRaiz({
    required this.rede,
    required this.chaveConvidador,
  });

  final IndicacoesRede rede;
  final String chaveConvidador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rotulo = rede.rotuloExibir(chaveConvidador);
    final diretos = rede.indicadosDiretosDe(chaveConvidador)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    if (diretos.isEmpty) {
      return Text(
        'Nenhum cadastro tem «Indicação» igual a este nome — não há ramos.',
        style: tema.textTheme.bodyMedium,
      );
    }

    final alcance = rede.alcanceSubarvore(chaveConvidador);

    return Material(
      color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: tema.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('arvore-raiz-$chaveConvidador'),
          initiallyExpanded: true,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_tree_rounded, color: tema.colorScheme.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Raiz — nível anterior da rede',
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6, left: 36),
            child: Text(
              '${diretos.length} ${diretos.length == 1 ? 'ramo fixado neste primeiro nível' : 'ramos neste primeiro nível'} · '
              '${alcance.pessoasNaRede} pessoa(s) na árvore · ${alcance.votosNaRede} votos na sub-rede',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
          childrenPadding: EdgeInsets.zero,
          children: diretos.map((v) => _NoPiramideTile(rede: rede, votante: v, nivel: 0)).toList(),
        ),
      ),
    );
  }
}

class _NoPiramideTile extends StatelessWidget {
  const _NoPiramideTile({
    required this.rede,
    required this.votante,
    required this.nivel,
  });

  final IndicacoesRede rede;
  final Votante votante;
  final int nivel;

  Color _corTracoGalho(BuildContext context) {
    final base = Theme.of(context).colorScheme.outlineVariant;
    return Color.lerp(base, Theme.of(context).colorScheme.primary, (nivel * 0.12).clamp(0.0, 0.55))!;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ck = normalizarChaveIndicacao(votante.nome);
    final filhos = rede.indicadosDiretosDe(ck)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    final detalheLinha = _linhaDetalhesVotante(votante);
    final textoRamoFilhos =
        filhos.isEmpty ? 'Nenhum próximo nível registrado sob este nome' : 'expandir próximo nível (${filhos.length})';

    final traco = _corTracoGalho(context);

    Widget conteudo;
    if (filhos.isEmpty) {
      conteudo = ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        horizontalTitleGap: 8,
        leading: Icon(Icons.subdirectory_arrow_right_rounded, size: 22, color: traco),
        title: Text(
          votante.nome,
          style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$detalheLinha\n$textoRamoFilhos',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
      );
    } else {
      conteudo = ExpansionTile(
        key: PageStorageKey<String>('pyr-${votante.id}'),
        tilePadding: const EdgeInsets.only(left: 4, right: 8),
        title: Text(
          votante.nome,
          style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$detalheLinha · $textoRamoFilhos',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          maxLines: 3,
        ),
        initiallyExpanded: false,
        maintainState: true,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        iconColor: traco,
        collapsedIconColor: traco,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: traco, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filhos.map((f) => _NoPiramideTile(rede: rede, votante: f, nivel: nivel + 1)).toList(),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: 6.0 + nivel * 18, bottom: 6),
      child: Theme(
        data: tema.copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: tema.colorScheme.surface.withValues(alpha: nivel == 0 ? 1.0 : 0.74),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: conteudo,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: tema.colorScheme.primary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
