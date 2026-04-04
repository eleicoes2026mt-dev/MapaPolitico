import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/mensagem.dart';
import '../../../models/visita.dart';
import '../../agenda/providers/agenda_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../votantes/providers/votantes_provider.dart' show municipiosMTListProvider, refreshMunicipiosMTList;
import '../../../models/municipio.dart';
import '../providers/mensagens_provider.dart';

class MensagensScreen extends ConsumerWidget {
  const MensagensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _Header(),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Mensagens'),
              Tab(icon: Icon(Icons.cake_outlined), text: 'Aniversariantes'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _MensagensTab(),
                _AniversariantesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
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
    final hojeAsync = ref.watch(aniversariantesHojeProvider);
    final proximosAsync = ref.watch(aniversariantesProximos30Provider);
    final allAsync = ref.watch(aniversariantesProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (_) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(aniversariantesProvider);
          await ref.read(aniversariantesProvider.future).then((_) {}).onError((_, __) {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hoje ──────────────────────────────────────────────────────
            hojeAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (hoje) {
                if (hoje.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('🎂', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Text(
                            hoje.length == 1
                                ? '${hoje.first.nome} faz aniversário HOJE!'
                                : '${hoje.length} pessoas fazem aniversário HOJE!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...hoje.map((a) => _AniversarianteCard(aniversariante: a, destaque: true)),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // ── Próximos 30 dias ───────────────────────────────────────────
            proximosAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (proximos) {
                if (proximos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.cake_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('Nenhum aniversário nos próximos 30 dias.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            'Cadastre datas de nascimento nos apoiadores e assessores para aparecerem aqui.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próximos 30 dias', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...proximos.map((a) => _AniversarianteCard(aniversariante: a)),
                  ],
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AniversarianteCard extends StatelessWidget {
  const _AniversarianteCard({required this.aniversariante, this.destaque = false});
  final Aniversariante aniversariante;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = aniversariante;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: destaque
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(destaque ? '🎂' : '🎁', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.nome, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tipoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tipoLabel, style: theme.textTheme.labelSmall?.copyWith(color: tipoColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destaque
                        ? '${a.idadeAnos} anos hoje! — ${DateFormat('dd/MM').format(a.dataNascimento)}'
                        : '${a.diasParaAniversario} dias — ${DateFormat('dd/MM').format(a.dataNascimento)} (${a.idadeAnos + 1} anos)',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botão WhatsApp
            if (a.whatsappUrl.isNotEmpty)
              Tooltip(
                message: 'Enviar felicitação pelo WhatsApp',
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    final uri = Uri.parse(a.whatsappUrl);
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

