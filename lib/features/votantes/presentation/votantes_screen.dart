import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/presentation/desktop_drag_scroll_behavior.dart';
import '../../../core/utils/municipio_resolver.dart'
    show municipioIdParaNomeCidade, municipioIdResolvidoParaApoiador;
import '../../apoiadores/presentation/utils/apoiadores_form_utils.dart'
    show
        cepSoDigitos,
        formatCepDisplayFromDigits,
        formatTelefoneBrFromDigits,
        telefoneSoDigitos;
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/profile.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show meuAssessorRegistroProvider;
import '../../assessores/providers/gestao_campanha_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mapa/data/mt_municipios_coords.dart';
import '../domain/indicacoes_rede.dart';
import '../providers/votantes_provider.dart';
import 'widgets/amigos_gilberto_dados_form_fields.dart';

class VotantesScreen extends ConsumerStatefulWidget {
  const VotantesScreen({super.key});

  @override
  ConsumerState<VotantesScreen> createState() => _VotantesScreenState();
}

class _VotantesScreenState extends ConsumerState<VotantesScreen> {
  static const int _cadastrosPorPagina = 20;

  String _query = '';
  String _cidadeFilter = '';

  /// Página atual (0-based).
  int _paginaLista = 0;

  Future<void> _abrirNovoOuEditar({Votante? existente}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VotanteFormDialog(existente: existente),
    );
  }

  Future<void> _promoverParaApoiador(Votante v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promover a apoiador'),
        content: Text(
          'Criar cadastro de apoiador para "${v.nome}" e remover o registro de $kAmigosGilbertoLabel? '
          'É necessário ter município definido e a pessoa não pode estar vinculada a outro apoiador.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Promover')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(promoverVotanteParaApoiadorProvider)(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cadastro de $kAmigosGilbertoLabel promovido a apoiador.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _promoverParaAssessor(Votante v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promover a assessor'),
        content: Text(
          'Dar a "${v.nome}" permissões de equipa (assessor nesta campanha)? '
          'O registro sai da lista de $kAmigosGilbertoLabel. '
          'As indicações e convites já feitos continuam ligados ao perfil da pessoa (UUID)—os relatórios de rede são preservados. '
          'A própria pessoa deve sair da app e voltar a entrar para ver o menu de assessor.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Promover')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(promoverVotanteParaAssessorProvider)(
        v.id,
        promotedProfileId: v.profileId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Promovido a assessor: convites/indicações passados mantêm-se; peça logout/login na conta dessa pessoa.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _confirmarExcluir(Votante v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir cadastro ($kAmigosGilbertoLabel)'),
        content: Text('Remover "${v.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(removerVotanteProvider)(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cadastro de $kAmigosGilbertoLabel removido.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeGestao = ref.watch(podeGestaoCampanhaCompletaProvider);
    final podeCadastrar = profile?.role == 'candidato' ||
        profile?.role == 'assessor' ||
        profile?.role == 'apoiador' ||
        profile?.role == 'votante';
    final podePromoverApoiador =
        profile?.role == 'candidato' || profile?.role == 'assessor';
    final podeExcluirVotante = podeGestao && !(profile?.cadastroViaQr ?? false);

    final list = ref.watch(votantesListProvider);
    final apoiadoresAsync = ref.watch(apoiadoresListProvider);
    final meuCadastroApoiador = profile?.role == 'apoiador'
        ? ref.watch(meuApoiadorProvider).valueOrNull
        : null;
    final apoiadorPorId = Map<String, String>.fromEntries(
      (apoiadoresAsync.valueOrNull ?? []).map((a) => MapEntry(a.id, a.nome)),
    );
    final meId = meuCadastroApoiador?.id;
    final meNome = meuCadastroApoiador?.nome.trim() ?? '';
    if (meId != null && meId.isNotEmpty && meNome.isNotEmpty) {
      apoiadorPorId[meId] = meNome;
    }

    final votantes = list.valueOrNull ?? [];
    final votosTotal = votantes.fold<int>(0, (a, v) => a + v.qtdVotosFamilia);
    var filtered = List<Votante>.from(votantes);
    if (_query.isNotEmpty) {
      filtered = filtered
          .where((v) => v.nome.toLowerCase().contains(_query.toLowerCase()))
          .toList();
    }
    if (_cidadeFilter.isNotEmpty) {
      final q = _cidadeFilter.toLowerCase();
      filtered = filtered.where((v) {
        final nome = v.cidadeDisplay.toLowerCase();
        return nome.contains(q);
      }).toList();
    }
    filtered.sort(
      (a, b) => a.nome
          .trim()
          .toLowerCase()
          .compareTo(b.nome.trim().toLowerCase()),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(votantesListProvider);
        ref.invalidate(municipiosMTListProvider);
        ref.invalidate(meuApoiadorProvider);
        await ref
            .read(votantesListProvider.future)
            .then((_) {})
            .onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kAmigosGilbertoLabel,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const EstadoMTBadge(compact: true),
              ],
            ),
            if (profile?.role == 'apoiador') ...[
              const SizedBox(height: 8),
              Text(
                'Cadastre pessoas da sua rede com cidade em MT para somarem na estimativa e aparecerem no mapa regional.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar em $kAmigosGilbertoLabel...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() {
                          _query = v;
                          _paginaLista = 0;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Filtrar por cidade...',
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        onChanged: (v) => setState(() {
                          _cidadeFilter = v;
                          _paginaLista = 0;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconButton.outlined(
                      tooltip:
                          'Dashboard da rede de indicações — quem indicou a quem e pirâmide',
                      icon: const Icon(Icons.hub_rounded),
                      onPressed: () =>
                          context.push('/dashboard-indicacoes-amigos'),
                    ),
                    if (podeCadastrar)
                      FilledButton.icon(
                        onPressed: () => _abrirNovoOuEditar(),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo — $kAmigosGilbertoLabel'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(label: Text('${filtered.length} cadastrados')),
                const SizedBox(width: 8),
                Chip(label: Text('$votosTotal votos estimados')),
              ],
            ),
            const SizedBox(height: 16),
            list.when(
              data: (_) {
                final totalFiltrados = filtered.length;
                final maxPaginaIdx = totalFiltrados == 0
                    ? 0
                    : (totalFiltrados - 1) ~/ _cadastrosPorPagina;
                final paginaSafe =
                    totalFiltrados == 0 ? 0 : min(_paginaLista, maxPaginaIdx);
                final ini = paginaSafe * _cadastrosPorPagina;
                final fim = ini + _cadastrosPorPagina > totalFiltrados
                    ? totalFiltrados
                    : ini + _cadastrosPorPagina;
                final paginaItens =
                    filtered.sublist(ini.clamp(0, totalFiltrados), fim);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VotantesTable(
                      votantes: paginaItens,
                      apoiadorPorId: apoiadorPorId,
                      podePromoverApoiador: podePromoverApoiador,
                      podeExcluir: podeExcluirVotante,
                      onEdit: (v) => _abrirNovoOuEditar(existente: v),
                      onDelete: _confirmarExcluir,
                      onPromoverApoiador: _promoverParaApoiador,
                      onPromoverAssessor: _promoverParaAssessor,
                    ),
                    if (totalFiltrados > _cadastrosPorPagina) ...[
                      const SizedBox(height: 12),
                      _PaginaListaAmigos(
                        totalItens: totalFiltrados,
                        porPagina: _cadastrosPorPagina,
                        paginaAtualVisual: paginaSafe,
                        maxPaginaIdx: maxPaginaIdx,
                        primeiroIndiceLista: ini,
                        ultimoIndiceListaExclusivo: fim,
                        onAnterior: paginaSafe > 0
                            ? () =>
                                setState(() => _paginaLista = paginaSafe - 1)
                            : null,
                        onSeguinte: paginaSafe < maxPaginaIdx
                            ? () =>
                                setState(() => _paginaLista = paginaSafe + 1)
                            : null,
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erro: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

String _instagramCelulaVotante(String? raw) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return '—';
  if (s.length > 28) return '${s.substring(0, 25)}…';
  return s;
}

/// Paginação abaixo da tabela («20 em 20»).
class _PaginaListaAmigos extends StatelessWidget {
  const _PaginaListaAmigos({
    required this.totalItens,
    required this.porPagina,
    required this.paginaAtualVisual,
    required this.maxPaginaIdx,
    required this.primeiroIndiceLista,
    required this.ultimoIndiceListaExclusivo,
    required this.onAnterior,
    required this.onSeguinte,
  });

  final int totalItens;
  final int porPagina;
  final int paginaAtualVisual;
  final int maxPaginaIdx;
  final int primeiroIndiceLista;
  final int ultimoIndiceListaExclusivo;
  final VoidCallback? onAnterior;
  final VoidCallback? onSeguinte;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final de = primeiroIndiceLista + 1;
    final ate = ultimoIndiceListaExclusivo;
    final numPaginas = maxPaginaIdx + 1;
    final mostraUm = ate == 0 ? '—' : '$de';

    return Material(
      color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Mostrando $mostraUm–$ate de $totalItens (até $porPagina por página)',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Página anterior',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onAnterior,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Página ${paginaAtualVisual + 1} de $numPaginas',
                    style: tema.textTheme.labelLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Página seguinte',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: onSeguinte,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «Indicação» na tabela (mesmo critério da rede): convite salvo → apoiador → candidato fallback.
String _indicacaoCelulaVotante(Votante v, Map<String, String> apoiadorPorId) =>
    textoIndicacaoResolvidoAmigosGilberto(v, apoiadorPorId);

/// «Apoiador»: nome na rede de amigos quando há `apoiador_id`; senão o nome de quem registrou (`convite_por_nome`).
String _apoiadorCelulaVotante(Votante v, Map<String, String> apoiadorPorId) {
  final aid = v.apoiadorId?.trim();
  if (aid != null && aid.isNotEmpty) {
    final n = apoiadorPorId[aid]?.trim();
    if (n != null && n.isNotEmpty) return n;
  }
  final conv = v.convitePorNome?.trim();
  if (conv != null && conv.isNotEmpty) return conv;
  return '—';
}

enum _PromoverDestinoCadastroAmigo { apoiador, assessor }

/// Menu para promover cadastro público como apoiador ou assessor da campanha.
class _MenuPromoverCadastroAmigo extends StatelessWidget {
  const _MenuPromoverCadastroAmigo({
    required this.v,
    required this.podeOpcaoApoiador,
    required this.podeOpcaoAssessor,
    required this.iconSize,
    required this.onPromoverApoiador,
    required this.onPromoverAssessor,
  });

  final Votante v;
  /// Município definido, sem apoiador.
  final bool podeOpcaoApoiador;
  /// Conta ligada (`profile_id`) e e-mail.
  final bool podeOpcaoAssessor;
  final double iconSize;
  final void Function(Votante) onPromoverApoiador;
  final void Function(Votante) onPromoverAssessor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PromoverDestinoCadastroAmigo>(
      tooltip: 'Promover cadastro',
      enabled: podeOpcaoApoiador || podeOpcaoAssessor,
      onSelected: (d) {
        switch (d) {
          case _PromoverDestinoCadastroAmigo.apoiador:
            onPromoverApoiador(v);
          case _PromoverDestinoCadastroAmigo.assessor:
            onPromoverAssessor(v);
        }
      },
      icon: Icon(Icons.workspace_premium_outlined, size: iconSize),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: _PromoverDestinoCadastroAmigo.apoiador,
          enabled: podeOpcaoApoiador,
          child: const Text('Promover como apoiador'),
        ),
        PopupMenuItem(
          value: _PromoverDestinoCadastroAmigo.assessor,
          enabled: podeOpcaoAssessor,
          child: const Text('Promover como assessor'),
        ),
      ],
    );
  }
}

class _VotantesTable extends StatelessWidget {
  const _VotantesTable({
    required this.votantes,
    required this.apoiadorPorId,
    required this.podePromoverApoiador,
    required this.podeExcluir,
    required this.onEdit,
    required this.onDelete,
    required this.onPromoverApoiador,
    required this.onPromoverAssessor,
  });

  final List<Votante> votantes;
  final Map<String, String> apoiadorPorId;
  final bool podePromoverApoiador;
  final bool podeExcluir;
  final void Function(Votante) onEdit;
  final void Function(Votante) onDelete;
  final void Function(Votante) onPromoverApoiador;
  final void Function(Votante) onPromoverAssessor;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    ({bool base, bool apoiador, bool assessor}) promoverFlags(Votante v) {
      final baseEl = podePromoverApoiador && v.apoiadorId == null;
      final ap = baseEl && v.municipioId != null;
      final as = baseEl &&
          v.profileId != null &&
          v.profileId!.trim().isNotEmpty &&
          (v.email?.trim().isNotEmpty ?? false);
      return (base: baseEl, apoiador: ap, assessor: as);
    }

    if (isNarrow) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: votantes.length,
        itemBuilder: (_, i) {
          final v = votantes[i];
          final pf = promoverFlags(v);
          final cidade = v.cidadeDisplay.isNotEmpty
              ? displayNomeCidadeMT(v.cidadeDisplay)
              : '—';
          final ap = _apoiadorCelulaVotante(v, apoiadorPorId);
          final ind = _indicacaoCelulaVotante(v, apoiadorPorId);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(v.nome),
              subtitle: Text(
                '${v.telefone == null || v.telefone!.isEmpty ? "—" : formatTelefoneBrFromDigits(v.telefone)} • '
                'IG: ${_instagramCelulaVotante(v.linkInstagram)} • $cidade • ${v.abrangencia} • ${v.qtdVotosFamilia} voto(s) • Apoiador: $ap • Convite: $ind',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pf.base && (pf.apoiador || pf.assessor))
                    _MenuPromoverCadastroAmigo(
                      v: v,
                      podeOpcaoApoiador: pf.apoiador,
                      podeOpcaoAssessor: pf.assessor,
                      iconSize: 24,
                      onPromoverApoiador: onPromoverApoiador,
                      onPromoverAssessor: onPromoverAssessor,
                    ),
                  IconButton(
                      icon: const Icon(Icons.edit), onPressed: () => onEdit(v)),
                  if (podeExcluir)
                    IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => onDelete(v)),
                ],
              ),
            ),
          );
        },
      );
    }
    return Tooltip(
      message:
          'Pode clicar na tabela com o rato pressionado e arrastar lateralmente '
          '(ou use a rodinha/deslize no touchpad).',
      child: ScrollConfiguration(
        behavior: const DesktopDragScrollBehavior(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nome')),
              DataColumn(label: Text('Contato')),
              DataColumn(label: Text('Instagram')),
              DataColumn(label: Text('Cidade')),
              DataColumn(label: Text('Abrangência')),
              DataColumn(label: Text('Votos')),
              DataColumn(label: Text('Apoiador')),
              DataColumn(label: Text('Indicação')),
              DataColumn(label: Text('Ações')),
            ],
            rows: votantes.map((v) {
              final cidade = v.cidadeDisplay.isNotEmpty
                  ? displayNomeCidadeMT(v.cidadeDisplay)
                  : '—';
              final ap = _apoiadorCelulaVotante(v, apoiadorPorId);
              final ind = _indicacaoCelulaVotante(v, apoiadorPorId);
              final pf = promoverFlags(v);
              return DataRow(
                cells: [
                  DataCell(Text(v.nome)),
                  DataCell(Text(
                    v.telefone == null || v.telefone!.isEmpty
                        ? '—'
                        : formatTelefoneBrFromDigits(v.telefone),
                  )),
                  DataCell(Text(_instagramCelulaVotante(v.linkInstagram))),
                  DataCell(Text(displayNomeCidadeMT(cidade))),
                  DataCell(Text(v.abrangencia)),
                  DataCell(Text('${v.qtdVotosFamilia}')),
                  DataCell(Text(ap)),
                  DataCell(Text(ind)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pf.base && (pf.apoiador || pf.assessor))
                        _MenuPromoverCadastroAmigo(
                          v: v,
                          podeOpcaoApoiador: pf.apoiador,
                          podeOpcaoAssessor: pf.assessor,
                          iconSize: 22,
                          onPromoverApoiador: onPromoverApoiador,
                          onPromoverAssessor: onPromoverAssessor,
                        ),
                      IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => onEdit(v)),
                      if (podeExcluir)
                        IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => onDelete(v)),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _VotanteFormDialog extends ConsumerStatefulWidget {
  const _VotanteFormDialog({this.existente});

  final Votante? existente;

  @override
  ConsumerState<_VotanteFormDialog> createState() => _VotanteFormDialogState();
}

class _VotanteFormDialogState extends ConsumerState<_VotanteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  late final TextEditingController _qtd;
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  late final TextEditingController _linkInstagram;

  /// Indicação escolhida no dropdown (candidato editando). null = padrão da campanha.
  String? _indicacaoSelecionada;

  /// Chave normalizada (lista `listCidadesMTNomesNormalizados`), igual ao cadastro de apoiadores.
  String? _cidadeNomeNormalizado;
  String? _cidadeErro;
  String _abrangencia = 'Individual';
  bool _loading = false;

  /// Apoiador criando votante: preenche cidade padrão uma vez a partir do cadastro.
  bool _apoiadorPadraoCidadeAplicado = false;
  bool _postFrameDefaultApoiadorAgendado = false;

  /// Edição: sincronizar dropdown a partir de `municipio_id` (uma vez).
  bool _postFrameSyncEdicaoAgendado = false;

  /// Edição: pré-preencher indicação (candidato) — uma vez, após lista de apoiadores.
  bool _postFrameSyncIndicacaoAgendado = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existente;
    _nome = TextEditingController(text: v?.nome ?? '');
    _telefone =
        TextEditingController(text: formatTelefoneBrFromDigits(v?.telefone));
    _email = TextEditingController(text: v?.email ?? '');
    _qtd = TextEditingController(text: '${v?.qtdVotosFamilia ?? 1}');
    _cep = TextEditingController(text: formatCepDisplayFromDigits(v?.cep));
    _logradouro = TextEditingController(text: v?.logradouro ?? '');
    _numero = TextEditingController(text: v?.numero ?? '');
    _complemento = TextEditingController(text: v?.complemento ?? '');
    _linkInstagram = TextEditingController(text: v?.linkInstagram ?? '');
    // Indicação: pré-selecionada via convite_por_nome (preenchida depois via postFrameCallback).
    // Prioridade: nome do join > cidade_nome salvo > vazio
    final cidadeInicial = v?.municipioNome?.trim().isNotEmpty == true
        ? v!.municipioNome!
        : (v?.cidadeNome?.trim().isNotEmpty == true ? v!.cidadeNome! : null);
    if (cidadeInicial != null) {
      _cidadeNomeNormalizado = normalizarNomeMunicipioMT(cidadeInicial);
    }
    _abrangencia = v?.abrangencia ?? 'Individual';
    if (v != null) {
      _apoiadorPadraoCidadeAplicado = true;
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _qtd.dispose();
    _cep.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    _linkInstagram.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_cidadeNomeNormalizado == null ||
        _cidadeNomeNormalizado!.trim().isEmpty) {
      setState(() => _cidadeErro = 'Selecione o município.');
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cidadeNomeNormalizado == null ||
        _cidadeNomeNormalizado!.trim().isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      // Tenta resolver municipio_id — mas NÃO bloqueia se não conseguir.
      final municipios = await refreshMunicipiosMTList(ref);
      var municipioIdResolvido =
          municipioIdParaNomeCidade(_cidadeNomeNormalizado, municipios);
      municipioIdResolvido ??= municipioIdParaNomeCidade(
          displayNomeCidadeMT(_cidadeNomeNormalizado!), municipios);

      // Cidade em texto legível para salvar em cidade_nome.
      final cidadeTexto = displayNomeCidadeMT(_cidadeNomeNormalizado!);

      final qtd = int.tryParse(_qtd.text.trim()) ?? 1;
      final profile = ref.read(profileProvider).valueOrNull;
      final cadastroAvulsoQr = profile?.cadastroViaQr == true;
      final candidatoPodeAlterarIndicacao =
          profile?.role == 'candidato' && widget.existente != null;
      if (widget.existente != null) {
        await ref.read(atualizarVotanteProvider)(
          widget.existente!.id,
          AtualizarVotanteParams(
            nome: _nome.text.trim(),
            telefone: telefoneSoDigitos(_telefone.text).isEmpty
                ? null
                : telefoneSoDigitos(_telefone.text),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            municipioId: municipioIdResolvido,
            cidadeNome: cidadeTexto,
            abrangencia: _abrangencia,
            qtdVotosFamilia: qtd,
            cep: cepSoDigitos(_cep.text).isEmpty
                ? null
                : cepSoDigitos(_cep.text),
            logradouro: _logradouro.text.trim().isEmpty
                ? null
                : _logradouro.text.trim(),
            numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
            complemento: _complemento.text.trim().isEmpty
                ? null
                : _complemento.text.trim(),
            linkInstagram: _linkInstagram.text.trim().isEmpty
                ? null
                : _linkInstagram.text.trim(),
            atualizarLinkInstagram: true,
            atualizarConviteIndicacao: candidatoPodeAlterarIndicacao,
            convitePorNome: candidatoPodeAlterarIndicacao
                ? _indicacaoSelecionada
                : null,
          ),
        );
      } else {
        await ref.read(criarVotanteProvider)(
          NovoVotanteParams(
            nome: _nome.text.trim(),
            telefone: telefoneSoDigitos(_telefone.text).isEmpty
                ? null
                : telefoneSoDigitos(_telefone.text),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            municipioId: municipioIdResolvido,
            cidadeNome: cidadeTexto,
            abrangencia: _abrangencia,
            qtdVotosFamilia: qtd < 1 ? 1 : qtd,
            // `apoiador_id` só quando o papel é apoiador (provider); indicação e coluna «Apoiador»
            // usam `convite_por_*` preenchido pelo provider com quem submeteu o formulário.
            apoiadorId: null,
            cep: cepSoDigitos(_cep.text).isEmpty
                ? null
                : cepSoDigitos(_cep.text),
            logradouro: _logradouro.text.trim().isEmpty
                ? null
                : _logradouro.text.trim(),
            numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
            complemento: _complemento.text.trim().isEmpty
                ? null
                : _complemento.text.trim(),
            cadastroViaQr: cadastroAvulsoQr,
            linkInstagram: _linkInstagram.text.trim().isEmpty
                ? null
                : _linkInstagram.text.trim(),
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        final aviso = municipioIdResolvido == null
            ? ' (vínculo com mapa pendente — aplique as migrations do Supabase)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.existente != null ? "Cadastro atualizado" : "Cadastro concluído"} ($kAmigosGilbertoLabel)$aviso.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final munAsync = ref.watch(municipiosMTListProvider);
    return AlertDialog(
      title: Text(
        widget.existente != null
            ? 'Editar — $kAmigosGilbertoLabel'
            : 'Novo cadastro — $kAmigosGilbertoLabel',
      ),
      content: SizedBox(
        width: 440,
        child: munAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro ao carregar cidades: $e'),
          data: (municipios) {
            final apAsync = ref.watch(meuApoiadorProvider);
            final ex = widget.existente;
            if (ex != null &&
                !_postFrameSyncEdicaoAgendado &&
                _cidadeNomeNormalizado == null) {
              _postFrameSyncEdicaoAgendado = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                String? key;
                // Primeiro via municipio_id na lista do banco
                if (ex.municipioId != null) {
                  for (final m in municipios) {
                    if (m.id == ex.municipioId) {
                      key = normalizarNomeMunicipioMT(m.nome);
                      break;
                    }
                  }
                }
                // Fallback: cidade_nome salvo
                if (key == null &&
                    ex.cidadeNome != null &&
                    ex.cidadeNome!.trim().isNotEmpty) {
                  final tentKey = normalizarNomeMunicipioMT(ex.cidadeNome!);
                  if (listCidadesMTNomesNormalizados.contains(tentKey)) {
                    key = tentKey;
                  }
                }
                if (key != null && mounted) {
                  setState(() => _cidadeNomeNormalizado = key);
                }
              });
            }
            if (profile?.role == 'apoiador' &&
                widget.existente == null &&
                !_apoiadorPadraoCidadeAplicado &&
                !_postFrameDefaultApoiadorAgendado &&
                apAsync.hasValue) {
              _postFrameDefaultApoiadorAgendado = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _apoiadorPadraoCidadeAplicado) return;
                setState(() {
                  _apoiadorPadraoCidadeAplicado = true;
                  final ap = apAsync.valueOrNull;
                  // Tenta via municipio_id → lista carregada
                  final mid = municipioIdResolvidoParaApoiador(ap, municipios);
                  if (mid != null && mid.isNotEmpty) {
                    for (final m in municipios) {
                      if (m.id == mid) {
                        _cidadeNomeNormalizado =
                            normalizarNomeMunicipioMT(m.nome);
                        break;
                      }
                    }
                  }
                  // Fallback: texto de cidade_nome do apoiador (funciona sem municipios no banco)
                  if (_cidadeNomeNormalizado == null &&
                      ap?.cidadeNome != null) {
                    final key =
                        normalizarNomeMunicipioMT(ap!.cidadeNome!.trim());
                    if (key.isNotEmpty &&
                        listCidadesMTNomesNormalizados.contains(key)) {
                      _cidadeNomeNormalizado = key;
                    }
                  }
                });
              });
            }
            final listaApoiadoresAsync = ref.watch(apoiadoresListProvider);
            // Dropdown de indicação — monta opções ao primeiro build com dados.
            final mostrarDropdownIndicacao =
                profile?.role == 'candidato' && ex != null;
            List<String> opcoesIndicacao = [];
            if (mostrarDropdownIndicacao && listaApoiadoresAsync.hasValue) {
              final apois = listaApoiadoresAsync.valueOrNull ?? [];
              opcoesIndicacao = [
                kIndicacaoListaFallbackCandidato,
                ...apois.map((a) => a.nome).toSet().toList()..sort(),
              ];
              if (!_postFrameSyncIndicacaoAgendado) {
                _postFrameSyncIndicacaoAgendado = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final snap = widget.existente;
                  if (snap == null) return;
                  final apMap = Map<String, String>.fromEntries(
                    apois.map((a) => MapEntry(a.id, a.nome)),
                  );
                  final resolvidoAtual =
                      textoIndicacaoResolvidoAmigosGilberto(snap, apMap);
                  setState(() {
                    _indicacaoSelecionada = opcoesIndicacao.contains(resolvidoAtual)
                        ? resolvidoAtual
                        : kIndicacaoListaFallbackCandidato;
                  });
                });
              }
            }
            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmigosGilbertoDadosFormFields(
                      nome: _nome,
                      telefone: _telefone,
                      email: _email,
                      qtd: _qtd,
                      linkInstagram: _linkInstagram,
                      cep: _cep,
                      logradouro: _logradouro,
                      numero: _numero,
                      complemento: _complemento,
                      selectedCidadeKey: _cidadeNomeNormalizado,
                      cidadeErro: _cidadeErro,
                      onCidadeSelected: (k) => setState(() {
                        if (k != null && k.trim().isNotEmpty) {
                          _cidadeNomeNormalizado = k;
                          _cidadeErro = null;
                        }
                      }),
                      abrangencia: _abrangencia,
                      onAbrangenciaChanged: (novo) => setState(() {
                        _abrangencia = novo;
                        if (novo == 'Individual') _qtd.text = '1';
                      }),
                      emailValidator: (v) {
                        if (widget.existente != null) return null;
                        return amigosGilbertoEmailValidatorPainel(v);
                      },
                      footerWidget:
                          widget.existente == null && profile != null
                              ? _VinculoCadastroNovoVotante(
                                  theme: theme,
                                  profile: profile,
                                )
                              : null,
                    ),
                    if (mostrarDropdownIndicacao) ...[
                      const SizedBox(height: 16),
                      listaApoiadoresAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (_) => InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Indicação',
                            helperText:
                                'Nome nas colunas «Indicação» e «Apoiador» desta lista.',
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: opcoesIndicacao.contains(_indicacaoSelecionada)
                                  ? _indicacaoSelecionada
                                  : (opcoesIndicacao.isNotEmpty
                                      ? kIndicacaoListaFallbackCandidato
                                      : null),
                              isExpanded: true,
                              isDense: true,
                              items: opcoesIndicacao
                                  .map(
                                    (n) => DropdownMenuItem<String>(
                                      value: n,
                                      child: Text(n),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _indicacaoSelecionada = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _salvar,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _VinculoCadastroNovoVotante extends ConsumerWidget {
  const _VinculoCadastroNovoVotante({
    required this.theme,
    required this.profile,
  });

  final ThemeData theme;
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (profile.role) {
      case 'candidato':
        final nome = profile.fullName?.trim().isNotEmpty == true
            ? profile.fullName!
            : (profile.email ?? 'Candidato');
        return _vinculoCadastroCard(
          theme: theme,
          icon: Icons.how_to_vote_outlined,
          label: 'Cadastro pelo candidato',
          destaque: nome,
          subtitulo:
              'Este cadastro ($kAmigosGilbertoLabel) entra na campanha direto pelo candidato (sem vínculo a apoiador).',
        );
      case 'assessor':
        return ref.watch(meuAssessorRegistroProvider).when(
              data: (a) {
                final nome = a?.nome.trim().isNotEmpty == true
                    ? a!.nome
                    : 'Seu cadastro de assessor';
                return _vinculoCadastroCard(
                  theme: theme,
                  icon: Icons.badge_outlined,
                  label: 'Vinculado ao assessor',
                  destaque: nome,
                  subtitulo:
                      'O cadastro fica na rede como registro do assessor logado. Não é possível alterar aqui.',
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _vinculoCadastroCard(
                theme: theme,
                icon: Icons.badge_outlined,
                label: 'Vinculado ao assessor',
                destaque: 'Assessor',
                subtitulo: 'Cadastro na rede do assessor logado.',
              ),
            );
      case 'votante':
        return _vinculoCadastroCard(
          theme: theme,
          icon: Icons.link_rounded,
          label: 'Cadastro pelo link da campanha',
          destaque: kAmigosGilbertoLabel,
          subtitulo:
              'Ao salvar, você entra na rede do candidato e passa a aparecer na lista de $kAmigosGilbertoLabel do deputado.',
        );
      case 'apoiador':
        return ref.watch(meuApoiadorProvider).when(
              data: (ap) {
                final nome = ap?.nome.trim().isNotEmpty == true
                    ? ap!.nome
                    : 'Seu cadastro de apoiador';
                return _vinculoCadastroCard(
                  theme: theme,
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Vinculado ao seu apoiador',
                  destaque: nome,
                  subtitulo:
                      'Será ligado automaticamente ao seu cadastro de apoiador. Não é possível trocar.',
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _vinculoCadastroCard(
                theme: theme,
                icon: Icons.volunteer_activism_outlined,
                label: 'Vinculado ao apoiador',
                destaque: 'Apoiador',
                subtitulo: 'Vínculo automático ao seu perfil de apoiador.',
              ),
            );
      default:
        return const SizedBox.shrink();
    }
  }
}

Widget _vinculoCadastroCard({
  required ThemeData theme,
  required IconData icon,
  required String label,
  required String destaque,
  required String subtitulo,
}) {
  return Material(
    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  destaque,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitulo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline,
                size: 18, color: theme.colorScheme.outline),
          ),
        ],
      ),
    ),
  );
}
