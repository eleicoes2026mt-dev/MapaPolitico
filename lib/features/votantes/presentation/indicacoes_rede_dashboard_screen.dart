import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../models/apoiador.dart';
import '../../../models/votante.dart';
import '../../auth/providers/auth_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../apoiadores/presentation/utils/apoiadores_form_utils.dart'
    show formatTelefoneBrFromDigits;
import '../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT;
import '../domain/indicacoes_rede.dart';
import '../providers/votantes_provider.dart';

/// Painel de rede de indicações (coluna *Indicação* / convite) para $kAmigosGilbertoLabel.
class IndicacoesRedeDashboardScreen extends ConsumerStatefulWidget {
  const IndicacoesRedeDashboardScreen({super.key});

  @override
  ConsumerState<IndicacoesRedeDashboardScreen> createState() =>
      _IndicacoesRedeDashboardScreenState();
}

class _IndicacoesRedeDashboardScreenState
    extends ConsumerState<IndicacoesRedeDashboardScreen> {
  final _filtroRanking = TextEditingController();
  String _filtro = '';
  String? _convidadorSelecionado;
  bool _listarTodosIndicadoresNaLateral = false;

  @override
  void dispose() {
    _filtroRanking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;

    /// Só conta com [meuApoiadorProvider]; fora desse papel devolve dados vazios.
    final AsyncValue<Apoiador?> estadoCadastroMeuPerfil =
        profile?.role == 'apoiador'
            ? ref.watch(meuApoiadorProvider)
            : const AsyncValue.data(null);

    final modoSubRedeSozinhaVotantePub = profile?.role == 'votante';

    final async = ref.watch(votantesIndicacaoRedeListProvider);

    final appTitulo = modoSubRedeSozinhaVotantePub
        ? 'Minhas indicações'
        : 'Rede de indicações';

    return Scaffold(
      appBar: AppBar(
        title: Text(appTitulo),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(votantesListProvider);
              ref.invalidate(votantesIndicacaoRedeListProvider);
              ref.invalidate(apoiadoresListProvider);
              ref.invalidate(meuApoiadorProvider);
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (votantes) {
          if (profile?.role == 'apoiador') {
            if (estadoCadastroMeuPerfil.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (estadoCadastroMeuPerfil.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Erro ao carregar o seu cadastro de apoiador. Toque em «Atualizar» no topo '
                    'e verifique se a conta ficou bem vinculada.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          }

          final cadastroUsuarioApoiador = profile?.role == 'apoiador'
              ? estadoCadastroMeuPerfil.valueOrNull
              : null;
          final nomeNormalizadoCadastro =
              cadastroUsuarioApoiador?.nome.trim() ?? '';

          if (profile?.role == 'apoiador') {
            if (cadastroUsuarioApoiador == null ||
                nomeNormalizadoCadastro.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Conta reconhecida como apoiador, mas não há linha em «apoiadores» com nome válido ligada '
                    'a este login. Solicite ao candidato/assessor o reenvio do convite ou peça revisão ao apoio.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              );
            }
          }

          final apoiadores =
              ref.watch(apoiadoresListProvider).valueOrNull ?? [];
          final apoiadorIdParaNome = Map<String, String>.fromEntries(
            apoiadores.map((a) => MapEntry(a.id, a.nome)),
          );
          if (cadastroUsuarioApoiador != null &&
              nomeNormalizadoCadastro.isNotEmpty) {
            apoiadorIdParaNome[cadastroUsuarioApoiador.id] =
                nomeNormalizadoCadastro;
          }

          final rede = IndicacoesRede.fromVotantes(
            votantes,
            apoiadorIdParaNome: apoiadorIdParaNome,
          );

          /// Quem faz login como apoiador vê apenas os registos já filtrados no provider;
          /// a lista à esquerda continua igual (indicadores **nesta mesma vista** da rede).
          Votante? meuCadastroVotante;
          String nomeParaChaveSubRedePub = '';
          if (modoSubRedeSozinhaVotantePub && profile != null) {
            for (final v in votantes) {
              if (v.profileId != null && v.profileId == profile.id) {
                meuCadastroVotante = v;
                break;
              }
            }
            final nLinha = meuCadastroVotante?.nome.trim() ?? '';
            final nPerfil = profile.fullName?.trim() ?? '';
            nomeParaChaveSubRedePub = nLinha.isNotEmpty
                ? nLinha
                : (nPerfil.isNotEmpty ? nPerfil : '');
          }

          final chaveRaizVotante = nomeParaChaveSubRedePub.isEmpty
              ? ''
              : normalizarChaveIndicacao(nomeParaChaveSubRedePub);

          final chaveRaizPreferidaApoiador = nomeNormalizadoCadastro.isEmpty
              ? ''
              : normalizarChaveIndicacao(nomeNormalizadoCadastro);

          final rankingKeys = modoSubRedeSozinhaVotantePub
              ? (chaveRaizVotante.isEmpty ? <String>[] : [chaveRaizVotante])
              : rede.rankingConvidadores(
                  filtroNome: _filtro,
                  listarTodosIndicadoresDaColuna:
                      _listarTodosIndicadoresNaLateral,
                );

          if (!modoSubRedeSozinhaVotantePub &&
              _convidadorSelecionado != null &&
              !rankingKeys.contains(_convidadorSelecionado)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _convidadorSelecionado = null);
            });
          }

          Future<void> onPull() async {
            ref.invalidate(votantesListProvider);
            ref.invalidate(votantesIndicacaoRedeListProvider);
            ref.invalidate(apoiadoresListProvider);
            ref.invalidate(meuApoiadorProvider);
            await ref
                .read(votantesIndicacaoRedeListProvider.future)
                .then((_) {})
                .onError((_, __) {});
            await ref
                .read(apoiadoresListProvider.future)
                .then((_) {})
                .onError((_, __) {});
          }

          final tituloExibirRaizVotPub = nomeParaChaveSubRedePub.isNotEmpty
              ? nomeParaChaveSubRedePub
              : (profile?.fullName ?? '');

          /// Lista + painel de árvore quando o utilizador **não** é [votante] público só.
          /// Inclui seleção preferida do apoiador pela chave do próprio nome cadastrado.
          String? chavePainelRedePreferida() {
            final manual = _convidadorSelecionado;
            if (manual != null && rankingKeys.contains(manual)) return manual;
            if (chaveRaizPreferidaApoiador.isNotEmpty &&
                rankingKeys.contains(chaveRaizPreferidaApoiador)) {
              return chaveRaizPreferidaApoiador;
            }
            return rankingKeys.isNotEmpty ? rankingKeys.first : null;
          }

          /// Detalhes da árvore (painel direito / em baixo na vista estreita).
          Widget detalheBody() {
            if (modoSubRedeSozinhaVotantePub) {
              if (profile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (chaveRaizVotante.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Não encontramos um cadastro de $kAmigosGilbertoLabel ligado ao seu utilizador '
                      'ou falta o nome no perfil. Complete o nome em «Meu perfil» ou contacte o apoio '
                      'se o cadastro estiver incompleto.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return _PainelDetalhe(
                tema: theme,
                rede: rede,
                chaveConvidador: chaveRaizVotante,
                tituloTopoOverride: tituloExibirRaizVotPub.trim().isNotEmpty
                    ? tituloExibirRaizVotPub.trim()
                    : null,
                rotuloArvoreRaiz: tituloExibirRaizVotPub.trim().isNotEmpty
                    ? tituloExibirRaizVotPub.trim()
                    : null,
                modoMinhaSubRedeVotante: true,
              );
            }

            return _PainelDetalhe(
              tema: theme,
              rede: rede,
              chaveConvidador: chavePainelRedePreferida(),
            );
          }

          /// Perfil público [votante]: só esta sub-rede.
          if (modoSubRedeSozinhaVotantePub) {
            return RefreshIndicator(
              onRefresh: onPull,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Aqui só conta a sua sub-rede: pessoas que se cadastraram com o seu nome '
                                'na coluna Indicação (e os níveis seguintes quando estiverem indicados pelo nome).',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    detalheBody(),
                  ],
                ),
              ),
            );
          }

          final twoPane = MediaQuery.sizeOf(context).width >= 980;

          final painelRanking = _PainelRanking(
            tema: theme,
            rede: rede,
            votantesTodos: votantes,
            filtroController: _filtroRanking,
            onFiltroSubmitted: (_) =>
                setState(() => _filtro = _filtroRanking.text.trim()),
            onFiltroChanged: (_) {
              final t = _filtroRanking.text.trim();
              setState(() => _filtro = t);
            },
            rankingKeys: rankingKeys,
            nomesDistinctComConviteNaBase:
                rede.totalConvidadoresComIndicacoesRegistradas,
            entradasNaListaRaizes:
                rede.quantidadeIndicadoresNaListaPrioritariaRaiz,
            filtroRankingAtivo: _filtro.isNotEmpty,
            listarTodosNaLateral: _listarTodosIndicadoresNaLateral,
            onListarTodosNaLateralChanged: (sim) =>
                setState(() => _listarTodosIndicadoresNaLateral = sim),
            selecionado: chavePainelRedePreferida(),
            onSelecionar: (k) => setState(() => _convidadorSelecionado = k),
          );

          if (twoPane) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 392,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
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
        onPressed: () => context
            .go(modoSubRedeSozinhaVotantePub ? '/apoiador-home' : '/votantes'),
        icon: Icon(modoSubRedeSozinhaVotantePub
            ? Icons.home_rounded
            : Icons.checklist_rounded),
        label: Text(
            modoSubRedeSozinhaVotantePub ? 'Início' : kAmigosGilbertoLabel),
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
    required this.nomesDistinctComConviteNaBase,
    required this.entradasNaListaRaizes,
    required this.filtroRankingAtivo,
    required this.listarTodosNaLateral,
    required this.onListarTodosNaLateralChanged,
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
  final int nomesDistinctComConviteNaBase;
  final int entradasNaListaRaizes;
  final bool filtroRankingAtivo;
  final bool listarTodosNaLateral;
  final ValueChanged<bool> onListarTodosNaLateralChanged;
  final String? selecionado;
  final void Function(String?) onSelecionar;

  String _chipContagemLista() {
    if (filtroRankingAtivo) {
      final modo = listarTodosNaLateral
          ? 'lista completa'
          : '$entradasNaListaRaizes prioritários';
      return '$rankingKeys.length resultado(s) · $modo ($nomesDistinctComConviteNaBase distinto(s) na coluna)';
    }
    if (listarTodosNaLateral) {
      return '$rankingKeys.length todos os indicadores (coluna)';
    }
    if (entradasNaListaRaizes < nomesDistinctComConviteNaBase) {
      return '$entradasNaListaRaizes na lista ($nomesDistinctComConviteNaBase distinto(s) na coluna)';
    }
    return '$entradasNaListaRaizes indicadores';
  }

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
            style: tema.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            listarTodosNaLateral
                ? 'A lista inclui cada nome que apareceu como indicação na base '
                    '(interruptor «lista completa» está ligado).'
                : 'Por padrão só aparecem indicadores prioritários: quem entrou pela rede '
                    'de outro nome também listado fica apenas na árvore desse indicador.',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Material(
            color: tema.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              dense: true,
              title: Text(
                'Lista completa de indicadores',
                style: tema.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                listarTodosNaLateral
                    ? 'Desligue para ocultar de novo ramos já ligados à árvore de outro pai (lista mais limpa).'
                    : 'Ligue para listar todas as pessoas que constam como indicação, inclusive dentro da rede de outros.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: listarTodosNaLateral,
              onChanged: onListarTodosNaLateralChanged,
              secondary: Icon(
                listarTodosNaLateral
                    ? Icons.list_alt_rounded
                    : Icons.manage_search_rounded,
                color: tema.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                  icon: Icons.people_outline,
                  label: '${votantesTodos.length} cadastrados'),
              _StatChip(
                  icon: Icons.person_search_outlined,
                  label: _chipContagemLista()),
              _StatChip(
                  icon: Icons.share_outlined,
                  label: '${comInd.length} com indicação'),
              _StatChip(
                  icon: Icons.person_off_outlined,
                  label: '${semInd.length} sem indicação'),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: filtroController,
            decoration: InputDecoration(
              hintText: 'Buscar nome do indicador...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  nomesDistinctComConviteNaBase == 0
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
                final ativo =
                    selecionado == key || (selecionado == null && i == 0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: ativo
                        ? tema.colorScheme.primaryContainer
                            .withValues(alpha: 0.45)
                        : null,
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
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
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
    this.tituloTopoOverride,
    this.rotuloArvoreRaiz,
    this.modoMinhaSubRedeVotante = false,
  });

  final ThemeData tema;
  final IndicacoesRede rede;
  final String? chaveConvidador;

  /// Nome grande no topo (ex.: «votante» sem aparecer só como pai na lista).
  final String? tituloTopoOverride;

  /// Título literal na primeira linha da [ExpansionTile] da raíz.
  final String? rotuloArvoreRaiz;

  /// Textos curtos só para utilizadores `[role=votante]`.
  final bool modoMinhaSubRedeVotante;

  @override
  Widget build(BuildContext context) {
    if (chaveConvidador == null || chaveConvidador!.isEmpty) {
      return Center(
        child: Text(
          'Selecione um indicador na lista para ver os detalhes.',
          style: tema.textTheme.bodyLarge
              ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    final key = chaveConvidador!;
    final diretos = rede.indicadosDiretosDe(key)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final alcance = rede.alcanceSubarvore(key);
    final cabeca = tituloTopoOverride ?? rede.rotuloExibir(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cabeca,
          style: tema.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${diretos.length} pessoa(s) no primeiro ramo (${diretos.length == 1 ? 'indicado' : 'indicadas'} diretamente) · '
          '${alcance.pessoasNaRede - diretos.length} nos ramos seguintes · '
          '${alcance.votosNaRede} votos estimados em toda a árvore.',
          style: tema.textTheme.bodyMedium
              ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Text(
          modoMinhaSubRedeVotante ? 'A sua rede' : 'Árvore de indicações',
          style:
              tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          modoMinhaSubRedeVotante
              ? 'Começa pelo seu nome. Expanda cada linha para ver quem cada pessoa trouxe quando indicou pelo nome na rede.'
              : 'O indicador fica na raíz. Cada pessoa aparece apenas no ramo de quem a indicou; '
                  'expanda um nome para ver quem ele indicou a seguir.',
          style: tema.textTheme.bodySmall
              ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _ArvoreIndicacaoRaiz(
          rede: rede,
          chaveConvidador: key,
          rotuloRaizExplicito: rotuloArvoreRaiz,
          legendaPorBaixoTituloRaiz: modoMinhaSubRedeVotante
              ? 'Você na raíz — só estes fluxos aparecem'
              : 'Raiz — nível anterior da rede',
          textoSemFilhosExplicito: modoMinhaSubRedeVotante
              ? 'Ainda não há cadastros com o seu nome em Indicação. Quando alguém se inscrever assim, '
                  'a pessoa aparece aqui; se ela também indicar outras pelo nome dela, aparecem nos níveis abaixo ao expandir.'
              : null,
        ),
      ],
    );
  }
}

String _linhaDetalhesVotante(Votante v) {
  final cid = v.cidadeDisplay.trim().isEmpty
      ? '—'
      : displayNomeCidadeMT(v.cidadeDisplay);
  final tel = v.telefone == null || v.telefone!.isEmpty
      ? '—'
      : formatTelefoneBrFromDigits(v.telefone);
  return '$tel · $cid · ${v.qtdVotosFamilia} voto(s) · ${v.abrangencia}';
}

class _ArvoreIndicacaoRaiz extends StatelessWidget {
  const _ArvoreIndicacaoRaiz({
    required this.rede,
    required this.chaveConvidador,
    this.rotuloRaizExplicito,
    this.legendaPorBaixoTituloRaiz = 'Raiz — nível anterior da rede',
    this.textoSemFilhosExplicito,
  });

  final IndicacoesRede rede;
  final String chaveConvidador;
  final String? rotuloRaizExplicito;
  final String legendaPorBaixoTituloRaiz;
  final String? textoSemFilhosExplicito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rotulo = rotuloRaizExplicito ?? rede.rotuloExibir(chaveConvidador);
    final diretos = rede.indicadosDiretosDe(chaveConvidador)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    final alcance = rede.alcanceSubarvore(chaveConvidador);

    final msgSemRamificacao = textoSemFilhosExplicito ??
        'Nenhum cadastro tem «Indicação» igual a este nome — não há ramos.';

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
              Icon(Icons.account_tree_rounded,
                  color: tema.colorScheme.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      legendaPorBaixoTituloRaiz,
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
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
          childrenPadding: EdgeInsets.zero,
          children: diretos.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        msgSemRamificacao,
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ]
              : diretos
                  .map((v) => _NoPiramideTile(rede: rede, votante: v, nivel: 0))
                  .toList(),
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
    return Color.lerp(base, Theme.of(context).colorScheme.primary,
        (nivel * 0.12).clamp(0.0, 0.55))!;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final filhos = rede.indicadosDiretosApartirCadastro(votante);

    final detalheLinha = _linhaDetalhesVotante(votante);
    final textoRamoFilhos = filhos.isEmpty
        ? 'Nenhum próximo nível registrado sob este nome'
        : 'expandir próximo nível (${filhos.length})';

    final traco = _corTracoGalho(context);
    final temNovaRedeFilha = filhos.isNotEmpty;

    Widget conteudo;
    if (!temNovaRedeFilha) {
      conteudo = ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        horizontalTitleGap: 8,
        leading: Icon(Icons.subdirectory_arrow_right_rounded,
            size: 22, color: traco),
        title: Text(
          votante.nome,
          style:
              tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$detalheLinha\n$textoRamoFilhos',
          style: tema.textTheme.bodySmall
              ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
      );
    } else {
      conteudo = ExpansionTile(
        key: PageStorageKey<String>('pyr-${votante.id}'),
        tilePadding: const EdgeInsets.only(left: 4, right: 8),
        title: Text(
          votante.nome,
          style: tema.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: tema.colorScheme.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          '$detalheLinha · $textoRamoFilhos',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onPrimaryContainer.withValues(alpha: 0.92),
          ),
          maxLines: 3,
        ),
        initiallyExpanded: false,
        maintainState: true,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        iconColor: tema.colorScheme.primary,
        collapsedIconColor: tema.colorScheme.primary,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: traco, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filhos
                    .map((f) => _NoPiramideTile(
                        rede: rede, votante: f, nivel: nivel + 1))
                    .toList(),
              ),
            ),
          ),
        ],
      );
    }

    final corCartao = temNovaRedeFilha
        ? tema.colorScheme.primaryContainer
            .withValues(alpha: nivel == 0 ? 0.62 : 0.48)
        : tema.colorScheme.surface.withValues(alpha: nivel == 0 ? 1.0 : 0.74);

    final bordaCartao = temNovaRedeFilha
        ? BorderSide(
            color: tema.colorScheme.primary.withValues(alpha: 0.52),
            width: 1.5,
          )
        : BorderSide(
            color: tema.colorScheme.outlineVariant.withValues(alpha: 0.35));

    return Padding(
      padding: EdgeInsets.only(left: 6.0 + nivel * 18, bottom: 6),
      child: Theme(
        data: tema.copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: corCartao,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: bordaCartao,
          ),
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
