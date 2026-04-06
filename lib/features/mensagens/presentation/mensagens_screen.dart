import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/utils/whatsapp_launch.dart';
import '../../../core/widgets/cartao_parabens_aniversario.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/mensagem.dart';
import '../../../models/visita.dart';
import '../../agenda/providers/agenda_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT;
import '../../votantes/providers/votantes_provider.dart' show municipiosMTListProvider, refreshMunicipiosMTList;
import '../../../models/municipio.dart';
import '../providers/mensagens_provider.dart';

class MensagensScreen extends ConsumerStatefulWidget {
  const MensagensScreen({super.key});

  @override
  ConsumerState<MensagensScreen> createState() => _MensagensScreenState();
}

class _MensagensScreenState extends ConsumerState<MensagensScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncTabFromRoute() {
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    final idx = tab == 'aniversariantes' ? 1 : 0;
    if (_tabController.index != idx) {
      _tabController.index = idx;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabFromRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Mensagens'),
            Tab(icon: Icon(Icons.cake_outlined), text: 'Aniversariantes'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MensagensTab(),
              _AniversariantesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Mensagens', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const EstadoMTBadge(compact: true),
        ],
      ),
    );
  }
}

// ── Tab Mensagens ─────────────────────────────────────────────────────────────

class _MensagensTab extends ConsumerStatefulWidget {
  const _MensagensTab();

  @override
  ConsumerState<_MensagensTab> createState() => _MensagensTabState();
}

class _MensagensTabState extends ConsumerState<_MensagensTab> {
  Future<void> _abrirFormulario() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _NovaMensagemDialog(),
    );
    ref.invalidate(mensagensListProvider);
  }

  Future<void> _excluir(Mensagem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir mensagem'),
        content: Text('Remover "${m.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(excluirMensagemProvider)(m.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem removida.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _enviarPush(Mensagem m) async {
    try {
      final result = await ref.read(enviarPushMensagemProvider)(m);
      if (!mounted) return;
      final sent = result['sent'] ?? 0;
      final total = result['total'] ?? 0;
      final msg = total == 0
          ? 'Enviado! Nenhum dispositivo inscrito ainda.\n'
              'Vá em Configurações → ative Notificações para se inscrever.'
          : 'Enviado para $sent de $total dispositivos!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      // Mostra o erro REAL do servidor para facilitar diagnóstico
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: SelectableText('Erro ao enviar push:\n${e.toString().replaceFirst("Exception: ", "")}'),
        duration: const Duration(seconds: 8),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeEditar = profile?.role == 'candidato' || profile?.role == 'assessor';
    final listAsync = ref.watch(mensagensListProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mensagensListProvider);
        await ref.read(mensagensListProvider.future).then((_) {}).onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text('${listAsync.valueOrNull?.length ?? 0} mensagens'),
                ),
                const Spacer(),
                if (podeEditar)
                  FilledButton.icon(
                    onPressed: _abrirFormulario,
                    icon: const Icon(Icons.add),
                    label: const Text('Nova Mensagem'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            listAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => Text('Erro: $e'),
              data: (lista) {
                if (lista.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.send, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('Nenhuma mensagem', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Crie mensagens globais, por polo, por cidade (apoiadores e $kAmigosGilbertoLabel) ou privadas para assessores/apoiadores.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _MensagemCard(
                    mensagem: lista[i],
                    podeEditar: podeEditar,
                    onDelete: () => _excluir(lista[i]),
                    onNotificar: () => _enviarPush(lista[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de mensagem ──────────────────────────────────────────────────────────

class _MensagemCard extends StatelessWidget {
  const _MensagemCard({
    required this.mensagem,
    required this.podeEditar,
    required this.onDelete,
    required this.onNotificar,
  });

  final Mensagem mensagem;
  final bool podeEditar;
  final VoidCallback onDelete;
  final VoidCallback onNotificar;

  static const _escoposBroadcast = {'global', 'polo', 'performance', 'reuniao'};

  static String _tituloMenuPush(String escopo) {
    return _escoposBroadcast.contains(escopo)
        ? 'Enviar notificação (broadcast)'
        : 'Enviar notificação segmentada';
  }

  static final _escopoLabel = {
    'global': 'Global',
    'polo': 'Por polo',
    'cidade': 'Por cidade (apoiadores e $kAmigosGilbertoLabel)',
    'performance': 'Por performance',
    'reuniao': 'Reunião',
    'privada_assessores': 'Privada — assessores',
    'privada_apoiadores': 'Privada — apoiadores',
  };

  static const _escopoIcon = {
    'global': Icons.public,
    'polo': Icons.hub_outlined,
    'cidade': Icons.location_city_outlined,
    'performance': Icons.trending_up_outlined,
    'reuniao': Icons.event_outlined,
    'privada_assessores': Icons.admin_panel_settings_outlined,
    'privada_apoiadores': Icons.groups_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = mensagem;
    final enviada = m.enviadaEm != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _escopoIcon[m.escopo] ?? Icons.public,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.titulo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        _escopoLabel[m.escopo] ?? m.escopo,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                if (podeEditar)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'notify') onNotificar();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'notify',
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.notifications_active_outlined),
                          title: Text(_MensagemCard._tituloMenuPush(m.escopo)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (m.corpo != null && m.corpo!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(m.corpo!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  enviada ? Icons.check_circle : Icons.schedule,
                  size: 14,
                  color: enviada ? Colors.green : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  enviada
                      ? 'Enviada em ${DateFormat('dd/MM/yyyy HH:mm').format(m.enviadaEm!.toLocal())}'
                      : 'Não enviada por push',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: enviada ? Colors.green : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!enviada && podeEditar) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onNotificar,
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text('Enviar push'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diálogo Nova Mensagem ─────────────────────────────────────────────────────

class _NovaMensagemDialog extends ConsumerStatefulWidget {
  const _NovaMensagemDialog();

  @override
  ConsumerState<_NovaMensagemDialog> createState() => _NovaMensagemDialogState();
}

class _NovaMensagemDialogState extends ConsumerState<_NovaMensagemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _corpo = TextEditingController();
  String _escopo = 'global';
  String? _poloId;
  String? _municipioCidadeId;
  bool _enviarPush = false;
  bool _loading = false;

  @override
  void dispose() {
    _titulo.dispose();
    _corpo.dispose();
    super.dispose();
  }

  String _subtituloPush() {
    switch (_escopo) {
      case 'global':
        return 'Envia para todos com push ativado (broadcast).';
      case 'polo':
        return 'Envia para todos com push (broadcast). Refine o polo abaixo.';
      case 'cidade':
        return 'Apenas apoiadores e $kAmigosGilbertoLabel com conta na cidade selecionada.';
      case 'privada_assessores':
        return 'Apenas assessores ativos com conta no app.';
      case 'privada_apoiadores':
        return 'Apenas apoiadores com login vinculado (não excluídos).';
      default:
        return 'Notificação conforme abrangência.';
    }
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_escopo == 'polo' && (_poloId == null || _poloId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um polo regional.')));
      return;
    }
    if (_escopo == 'cidade' && (_municipioCidadeId == null || _municipioCidadeId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o município.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(criarMensagemProvider)(
        NovaMensagemParams(
          titulo: _titulo.text.trim(),
          corpo: _corpo.text.trim().isEmpty ? null : _corpo.text.trim(),
          escopo: _escopo,
          poloId: _escopo == 'polo' ? _poloId : null,
          municipiosIds: _escopo == 'cidade' && _municipioCidadeId != null ? [_municipioCidadeId!] : const [],
          enviarPush: _enviarPush,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_enviarPush ? 'Mensagem criada e notificação enviada!' : 'Mensagem criada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final polosAsync = ref.watch(polosRegioesListProvider);
    final munAsync = ref.watch(municipiosMTListProvider);

    final maxDialogW = min(480.0, MediaQuery.sizeOf(context).width - 48);

    return AlertDialog(
      title: const Text('Nova Mensagem'),
      content: SizedBox(
        width: maxDialogW,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titulo,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    hintText: 'Ex.: Reunião em Cuiabá — 15/04',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _corpo,
                  decoration: const InputDecoration(
                    labelText: 'Conteúdo da mensagem',
                    hintText: 'Descreva a mensagem para os apoiadores...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _escopo,
                  decoration: const InputDecoration(
                    labelText: 'Abrangência',
                    prefixIcon: Icon(Icons.public_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'global',
                      child: Text('Global — todos os usuários', overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                    const DropdownMenuItem(
                      value: 'privada_assessores',
                      child: Text('Privada — apenas assessores', overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                    const DropdownMenuItem(
                      value: 'privada_apoiadores',
                      child: Text('Privada — apenas apoiadores', overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                    DropdownMenuItem(
                      value: 'cidade',
                      child: Text(
                        'Por cidade — apoiadores e $kAmigosGilbertoLabel da cidade',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'polo',
                      child: Text('Por polo regional', overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _escopo = v ?? 'global';
                    _poloId = null;
                    _municipioCidadeId = null;
                  }),
                ),
                if (_escopo == 'polo') ...[
                  const SizedBox(height: 12),
                  polosAsync.when(
                    data: (polos) {
                      if (polos.isEmpty) {
                        return Text(
                          'Nenhum polo cadastrado.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _poloId != null && polos.any((p) => p.id == _poloId) ? _poloId : null,
                        decoration: const InputDecoration(
                          labelText: 'Polo regional *',
                          prefixIcon: Icon(Icons.hub_outlined),
                        ),
                        items: [
                          for (final p in polos)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.nome, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                        ],
                        onChanged: (v) => setState(() => _poloId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro ao carregar polos: $e', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
                if (_escopo == 'cidade') ...[
                  const SizedBox(height: 12),
                  munAsync.when(
                    data: (municipios) {
                      if (municipios.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Municípios indisponíveis.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await refreshMunicipiosMTList(ref);
                                if (context.mounted) setState(() {});
                              },
                              icon: const Icon(Icons.sync, size: 18),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        );
                      }
                      final ordenados = List<Municipio>.from(municipios)
                        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _municipioCidadeId != null && ordenados.any((m) => m.id == _municipioCidadeId)
                            ? _municipioCidadeId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Município *',
                          prefixIcon: Icon(Icons.location_city_outlined),
                          helperText: 'Só recebem quem tem perfil vinculado neste município.',
                        ),
                        items: [
                          for (final m in ordenados)
                            DropdownMenuItem(
                              value: m.id,
                              child: Text(m.nome, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                        ],
                        onChanged: (v) => setState(() => _municipioCidadeId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => OutlinedButton.icon(
                      onPressed: () async {
                        await refreshMunicipiosMTList(ref);
                        if (context.mounted) setState(() {});
                      },
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Carregar municípios'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Enviar notificação push'),
                  subtitle: Text(
                    _subtituloPush(),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 5,
                    softWrap: true,
                  ),
                  trailing: Switch(
                    value: _enviarPush,
                    onChanged: (v) => setState(() => _enviarPush = v),
                  ),
                ),
              ],
            ),
          ),
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Criar mensagem'),
        ),
      ],
    );
  }
}

// ── Tab Aniversariantes ───────────────────────────────────────────────────────

class _AniversariantesTab extends ConsumerWidget {
  const _AniversariantesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCandidato = ref.watch(profileProvider).valueOrNull?.isCandidato == true;
    final hojeAsync = ref.watch(aniversariantesHojeProvider);
    final proximosAsync = ref.watch(aniversariantesProximos30Provider);
    final allAsync = ref.watch(aniversariantesProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (todas) {
        if (todas.isEmpty) {
          return _AniversariantesEmptyState(
            icon: Icons.cake_outlined,
            titulo: 'Nenhuma data de nascimento cadastrada',
            subtitulo:
                'Inclua a data nos cadastros de apoiadores e assessores para acompanhar aniversários e fortalecer o relacionamento.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(aniversariantesProvider);
            await ref.read(aniversariantesProvider.future).then((_) {}).onError((_, __) {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendário de aniversários',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCandidato
                      ? 'Apoiadores e assessores com data informada. Como candidato, na seção Hoje o ícone do cartão ou o WhatsApp verde enviam o cartão de parabéns (imagem + mensagem); o visto indica que você já compartilhou hoje.'
                      : 'Apoiadores e assessores com data informada. Toque no WhatsApp para enviar uma mensagem.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                hojeAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (hoje) => _SecaoHoje(theme: theme, lista: hoje),
                ),
                const SizedBox(height: 8),
                proximosAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (proximos) => _SecaoProximos30(theme: theme, lista: proximos),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SecaoHoje extends StatelessWidget {
  const _SecaoHoje({required this.theme, required this.lista});

  final ThemeData theme;
  final List<Aniversariante> lista;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.wb_sunny_outlined, size: 20, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Text(
              'Hoje',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (lista.isEmpty)
          _PainelInfo(
            theme: theme,
            tonal: true,
            child: Text(
              'Ninguém faz aniversário hoje.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          _PainelInfo(
            theme: theme,
            tonal: true,
            destaque: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  child: Icon(Icons.cake_rounded, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    lista.length == 1
                        ? '${lista.first.nome} celebra aniversário hoje.'
                        : '${lista.length} pessoas celebram aniversário hoje.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...lista.map((a) => _AniversarianteCard(aniversariante: a, destaque: true)),
        ],
      ],
    );
  }
}

class _SecaoProximos30 extends StatelessWidget {
  const _SecaoProximos30({required this.theme, required this.lista});

  final ThemeData theme;
  final List<Aniversariante> lista;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Próximos 30 dias',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            if (lista.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${lista.length}',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (lista.isEmpty)
          _PainelInfo(
            theme: theme,
            tonal: false,
            child: Text(
              'Nenhum aniversário agendado para as próximas quatro semanas (além de hoje).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          )
        else
          ...lista.map((a) => _AniversarianteCard(aniversariante: a)),
      ],
    );
  }
}

class _PainelInfo extends StatelessWidget {
  const _PainelInfo({
    required this.theme,
    required this.child,
    this.tonal = false,
    this.destaque = false,
  });

  final ThemeData theme;
  final Widget child;
  final bool tonal;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tonal ? theme.colorScheme.primaryContainer.withValues(alpha: destaque ? 0.55 : 0.35) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: destaque ? theme.colorScheme.primary.withValues(alpha: 0.35) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );
  }
}

class _AniversariantesEmptyState extends StatelessWidget {
  const _AniversariantesEmptyState({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AniversarianteCard extends ConsumerStatefulWidget {
  const _AniversarianteCard({required this.aniversariante, this.destaque = false});

  final Aniversariante aniversariante;
  final bool destaque;

  @override
  ConsumerState<_AniversarianteCard> createState() => _AniversarianteCardState();
}

class _AniversarianteCardState extends ConsumerState<_AniversarianteCard> {
  bool _loadingParabens = false;
  bool? _jaEnviouParabens;

  @override
  void initState() {
    super.initState();
    if (widget.destaque) {
      _carregarPrefsParabens();
    }
  }

  @override
  void didUpdateWidget(covariant _AniversarianteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destaque && !oldWidget.destaque) {
      _carregarPrefsParabens();
    }
  }

  Future<void> _carregarPrefsParabens() async {
    final v = await ParabensAniversarioPrefs.jaEnviou(widget.aniversariante);
    if (mounted) setState(() => _jaEnviouParabens = v);
  }

  Future<void> _compartilharCartaoParabens() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null || !profile.isCandidato) return;
    if (_loadingParabens) return;
    setState(() => _loadingParabens = true);
    try {
      final ok = await shareCartaoParabensAniversario(
        context,
        aniversariante: widget.aniversariante,
        deputado: profile,
      );
      if (mounted && ok) {
        setState(() {
          _jaEnviouParabens = true;
          _loadingParabens = false;
        });
      } else if (mounted) {
        setState(() => _loadingParabens = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingParabens = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.aniversariante;
    final profile = ref.watch(profileProvider).valueOrNull;
    final mostrarCartaoParabens =
        widget.destaque && profile != null && profile.isCandidato;

    String tipoLabel;
    Color tipoColor;
    switch (a.tipo) {
      case 'apoiador':
        tipoLabel = 'Apoiador';
        tipoColor = theme.colorScheme.primary;
        break;
      case 'assessor':
        tipoLabel = 'Assessor';
        tipoColor = theme.colorScheme.secondary;
        break;
      default:
        tipoLabel = kAmigosGilbertoLabel;
        tipoColor = theme.colorScheme.tertiary;
    }

    final cidadeStr = a.municipioNome != null && a.municipioNome!.trim().isNotEmpty
        ? displayNomeCidadeMT(a.municipioNome!.trim())
        : null;
    final origemStr = a.origemLugarNome != null && a.origemLugarNome!.trim().isNotEmpty
        ? 'De: ${a.origemLugarNome!.trim()}'
        : null;
    final linhaLocal = <String>[
      if (cidadeStr != null) cidadeStr,
      if (origemStr != null) origemStr,
    ].join(' · ');

    final dataFmt = DateFormat('dd/MM').format(a.dataNascimento);
    final linhaDetalhe = widget.destaque
        ? '${a.idadeAnos} anos — $dataFmt'
        : '${a.diasParaAniversario} ${a.diasParaAniversario == 1 ? 'dia' : 'dias'} até o aniversário · $dataFmt · fará ${a.idadeAnos + 1} anos';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.destaque
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: ListTile(
          isThreeLine: true,
          titleAlignment: ListTileTitleAlignment.top,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: widget.destaque
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
            child: Icon(
              widget.destaque ? Icons.cake_outlined : Icons.card_giftcard_outlined,
              color: widget.destaque ? theme.colorScheme.primary : theme.colorScheme.onSecondaryContainer,
              size: 22,
            ),
          ),
          title: Text(
            a.nome,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (linhaLocal.isNotEmpty) ...[
                  Text(
                    linhaLocal,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  linhaDetalhe,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Chip(
                      label: Text(tipoLabel),
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: tipoColor.withValues(alpha: 0.12),
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: tipoColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.tipo == 'apoiador' &&
                        a.perfil != null &&
                        a.perfil!.trim().isNotEmpty)
                      Chip(
                        label: Text(
                          a.perfil!.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        side: BorderSide.none,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (a.tipo == 'assessor' &&
                        a.cargoAssessor != null &&
                        a.cargoAssessor!.trim().isNotEmpty)
                      Chip(
                        label: Text(
                          a.cargoAssessor!.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        side: BorderSide.none,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mostrarCartaoParabens) ...[
                if (_jaEnviouParabens == true) ...[
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Cartão de parabéns já compartilhado hoje',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.tertiary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Compartilhar cartão de parabéns (imagem)',
                  child: _loadingParabens
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : IconButton.filledTonal(
                          icon: const Icon(Icons.card_giftcard_rounded, size: 22),
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          ),
                          onPressed: _compartilharCartaoParabens,
                        ),
                ),
              ],
              if (a.whatsappUrl.isNotEmpty) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: mostrarCartaoParabens
                      ? 'Enviar cartão de parabéns no WhatsApp (imagem + mensagem)'
                      : (shouldOfferWhatsAppWebOrAppChoice()
                          ? 'WhatsApp (Web ou aplicativo no PC)'
                          : 'WhatsApp'),
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.chat, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                    ),
                    onPressed: _loadingParabens
                        ? null
                        : () async {
                            if (mostrarCartaoParabens) {
                              await _compartilharCartaoParabens();
                            } else {
                              await openWhatsAppForAniversariante(context, a);
                            }
                          },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

