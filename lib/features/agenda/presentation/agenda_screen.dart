import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/visita.dart';
import '../../auth/providers/auth_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../providers/agenda_provider.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime _mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _diaSelecionado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeEditar = profile?.role == 'candidato' || profile?.role == 'assessor';
    final isApoiador = profile?.role == 'apoiador';

    final visitasAsync = podeEditar
        ? ref.watch(todasVisitasProvider)
        : ref.watch(visitasProvider);

    final proximaAsync = isApoiador ? ref.watch(proximaVisitaMinhaCidadeProvider) : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(visitasProvider);
        ref.invalidate(todasVisitasProvider);
        ref.invalidate(proximaVisitaMinhaCidadeProvider);
        await Future.any([
          ref.read(visitasProvider.future).then((_) {}).onError((_, __) {}),
          ref.read(todasVisitasProvider.future).then((_) {}).onError((_, __) {}),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── Cabeçalho ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda de Visitas',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      podeEditar
                          ? 'Agende visitas às cidades — apoiadores serão notificados.'
                          : 'Próximas visitas do deputado à sua cidade.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),

          // ── Banner próxima visita (apoiador) ─────────────────────────────
          if (isApoiador && proximaAsync != null) ...[
            proximaAsync.when(
              data: (v) => v != null ? _ProximaVisitaBanner(visita: v) : const SizedBox.shrink(),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Calendário (candidato/assessor) ──────────────────────────────
          if (podeEditar) ...[
            visitasAsync.when(
              data: (visitas) => _MiniCalendario(
                mes: _mesSelecionado,
                visitas: visitas,
                diaSelecionado: _diaSelecionado,
                onMesAnterior: () => setState(() {
                  _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1);
                }),
                onProximoMes: () => setState(() {
                  _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1);
                }),
                onDiaTap: (d) => setState(() => _diaSelecionado = _diaSelecionado == d ? null : d),
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => Text('Erro: $e'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () => _abrirFormulario(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Visita'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ── Lista de visitas ──────────────────────────────────────────────
          visitasAsync.when(
            data: (todasVisitas) {
              final filtradas = _diaSelecionado != null
                  ? todasVisitas
                      .where((v) =>
                          v.dataReuniao.day == _diaSelecionado!.day &&
                          v.dataReuniao.month == _diaSelecionado!.month &&
                          v.dataReuniao.year == _diaSelecionado!.year)
                      .toList()
                  : todasVisitas
                      .where((v) => podeEditar ? true : v.isFutura)
                      .toList();

              if (filtradas.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.event_available, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _diaSelecionado != null
                              ? 'Nenhuma visita neste dia.'
                              : 'Nenhuma visita agendada.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtradas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _VisitaCard(
                  visita: filtradas[i],
                  podeEditar: podeEditar,
                  onEdit: () => _abrirFormulario(context, existente: filtradas[i]),
                  onDelete: () => _confirmarExcluir(context, filtradas[i]),
                  onNotificar: () => _notificar(filtradas[i]),
                ),
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

  Future<void> _abrirFormulario(BuildContext ctx, {Visita? existente}) async {
    await showDialog<void>(
      context: ctx,
      builder: (_) => _VisitaFormDialog(existente: existente),
    );
    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
  }

  Future<void> _confirmarExcluir(BuildContext ctx, Visita v) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir visita'),
        content: Text('Remover "${v.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(excluirVisitaProvider)(v.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visita removida.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _notificar(Visita v) async {
    // Confirmar antes de enviar
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar notificação'),
        content: Text(
          'Notificar todos os usuários com push ativado sobre a visita a "${v.municipioNome ?? v.titulo}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Notificar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final r = await supabase.functions.invoke('send-push', body: {
        'title': '📅 Visita: ${v.municipioNome ?? v.titulo}',
        'body':
            'O deputado visitará ${v.municipioNome ?? "sua cidade"} em ${v.dataHoraFormatada}.'
            '${v.localTexto != null ? " Local: ${v.localTexto}" : ""}',
        'url': '/#/agenda',
        'tag': 'visita-${v.id}',
      });

      // Registra a data de envio independente do resultado
      await supabase
          .from('reunioes')
          .update({'notificados_em': DateTime.now().toIso8601String()})
          .eq('id', v.id);
      ref.invalidate(visitasProvider);
      ref.invalidate(todasVisitasProvider);

      if (!mounted) return;
      final data = r.data as Map<String, dynamic>?;
      final sent = data?['sent'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notificação enviada para $sent dispositivos.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // Edge function não deployada ainda
      final naoDeployada = msg.contains('404') ||
          msg.contains('Failed to fetch') ||
          msg.contains('not found');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            naoDeployada
                ? 'Edge function "send-push" ainda não foi deployada no Supabase.\n'
                    'Execute: supabase functions deploy send-push'
                : 'Erro ao notificar: $msg',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }
}

// ── Mini Calendário ──────────────────────────────────────────────────────────

class _MiniCalendario extends StatelessWidget {
  const _MiniCalendario({
    required this.mes,
    required this.visitas,
    required this.diaSelecionado,
    required this.onMesAnterior,
    required this.onProximoMes,
    required this.onDiaTap,
  });

  final DateTime mes;
  final List<Visita> visitas;
  final DateTime? diaSelecionado;
  final VoidCallback onMesAnterior;
  final VoidCallback onProximoMes;
  final void Function(DateTime) onDiaTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hoje = DateTime.now();
    final primeiroDia = DateTime(mes.year, mes.month, 1);
    final diasNoMes = DateUtils.getDaysInMonth(mes.year, mes.month);
    final diasComVisita = <int>{
      for (final v in visitas)
        if (v.dataReuniao.year == mes.year && v.dataReuniao.month == mes.month) v.dataReuniao.day,
    };

    // Offset: weekday 1=seg, 7=dom → posição 0=seg
    final offset = (primeiroDia.weekday - 1) % 7;
    final totalCelulas = offset + diasNoMes;
    final rows = (totalCelulas / 7).ceil();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: onMesAnterior),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(mes),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: onProximoMes),
              ],
            ),
            Row(
              children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
                  .map((d) => Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            ...List.generate(rows, (row) {
              return Row(
                children: List.generate(7, (col) {
                  final idx = row * 7 + col;
                  final dia = idx - offset + 1;
                  if (dia < 1 || dia > diasNoMes) return const Expanded(child: SizedBox(height: 36));

                  final data = DateTime(mes.year, mes.month, dia);
                  final temVisita = diasComVisita.contains(dia);
                  final eHoje = data.year == hoje.year && data.month == hoje.month && data.day == hoje.day;
                  final eSelecionado = diaSelecionado != null &&
                      diaSelecionado!.day == dia &&
                      diaSelecionado!.month == mes.month &&
                      diaSelecionado!.year == mes.year;

                  Color? bgColor;
                  Color? fgColor;
                  if (eSelecionado) {
                    bgColor = theme.colorScheme.primary;
                    fgColor = theme.colorScheme.onPrimary;
                  } else if (eHoje) {
                    bgColor = theme.colorScheme.primaryContainer;
                    fgColor = theme.colorScheme.onPrimaryContainer;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onDiaTap(data),
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.all(2),
                        decoration: bgColor != null
                            ? BoxDecoration(color: bgColor, shape: BoxShape.circle)
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$dia',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: fgColor,
                                fontWeight: temVisita ? FontWeight.bold : null,
                              ),
                            ),
                            if (temVisita && !eSelecionado)
                              Positioned(
                                bottom: 3,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Card de visita ────────────────────────────────────────────────────────────

class _VisitaCard extends StatelessWidget {
  const _VisitaCard({
    required this.visita,
    required this.podeEditar,
    required this.onEdit,
    required this.onDelete,
    required this.onNotificar,
  });

  final Visita visita;
  final bool podeEditar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onNotificar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHoje = visita.isHoje;
    final isFutura = visita.isFutura;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHoje
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: isHoje
                        ? theme.colorScheme.primaryContainer
                        : isFutura
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('dd').format(visita.dataReuniao),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMM', 'pt_BR').format(visita.dataReuniao).toUpperCase(),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isHoje) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('HOJE', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              visita.titulo,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (visita.municipioNome != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              visita.municipioNome!,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      if (visita.hora != null && visita.hora!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(visita.hora!, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                      if (visita.localTexto != null && visita.localTexto!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                visita.localTexto!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (visita.descricao != null && visita.descricao!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          visita.descricao!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                      if (podeEditar && visita.notificadosEm != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Notificados em ${DateFormat('dd/MM HH:mm').format(visita.notificadosEm!.toLocal())}',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                if (podeEditar)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                      if (v == 'notify') onNotificar();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'notify', child: ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('Notificar todos'))),
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Excluir'))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner para apoiador ──────────────────────────────────────────────────────

class _ProximaVisitaBanner extends StatelessWidget {
  const _ProximaVisitaBanner({required this.visita});
  final Visita visita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.event, color: theme.colorScheme.primary, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visita.isHoje ? '🎉 O deputado está na sua cidade HOJE!' : '📅 Próxima visita do deputado',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  visita.dataHoraFormatada,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (visita.localTexto != null && visita.localTexto!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Local: ${visita.localTexto}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
                if (visita.descricao != null && visita.descricao!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    visita.descricao!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulário de visita ──────────────────────────────────────────────────────

class _VisitaFormDialog extends ConsumerStatefulWidget {
  const _VisitaFormDialog({this.existente});
  final Visita? existente;

  @override
  ConsumerState<_VisitaFormDialog> createState() => _VisitaFormDialogState();
}

class _VisitaFormDialogState extends ConsumerState<_VisitaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _local;
  late final TextEditingController _descricao;
  late final TextEditingController _hora;
  DateTime? _data;
  String? _municipioIdSelecionado;
  bool _visivelApoiadores = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existente;
    _titulo = TextEditingController(text: v?.titulo ?? '');
    _local = TextEditingController(text: v?.localTexto ?? '');
    _descricao = TextEditingController(text: v?.descricao ?? '');
    _hora = TextEditingController(text: v?.hora ?? '');
    _data = v?.dataReuniao;
    _municipioIdSelecionado = v?.municipioId;
    _visivelApoiadores = v?.visivelApoiadores ?? true;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _local.dispose();
    _descricao.dispose();
    _hora.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_data == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a data.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final params = NovaVisitaParams(
        titulo: _titulo.text.trim(),
        dataReuniao: _data!,
        hora: _hora.text.trim().isEmpty ? null : _hora.text.trim(),
        localTexto: _local.text.trim().isEmpty ? null : _local.text.trim(),
        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        municipioId: _municipioIdSelecionado,
        visivelApoiadores: _visivelApoiadores,
      );
      if (widget.existente != null) {
        await ref.read(atualizarVisitaProvider)(widget.existente!.id, params);
      } else {
        await ref.read(criarVisitaProvider)(params);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existente != null ? 'Visita atualizada.' : 'Visita agendada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _data = picked);
  }

  @override
  Widget build(BuildContext context) {
    final munAsync = ref.watch(municipiosMTListProvider);

    return AlertDialog(
      title: Text(widget.existente != null ? 'Editar Visita' : 'Nova Visita'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                // Data
                InkWell(
                  onTap: _selecionarData,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data *',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _data != null ? DateFormat('dd/MM/yyyy').format(_data!) : 'Selecione a data',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hora,
                  decoration: const InputDecoration(labelText: 'Horário (ex.: 09:00)', prefixIcon: Icon(Icons.access_time_outlined)),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 12),
                // Município
                munAsync.when(
                  data: (municipios) => DropdownButtonFormField<String?>(
                    value: _municipioIdSelecionado,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cidade', prefixIcon: Icon(Icons.location_city_outlined)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sem cidade específica')),
                      ...municipios.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nome, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _municipioIdSelecionado = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _local,
                  decoration: const InputDecoration(labelText: 'Local (rua, endereço, nome do estabelecimento)', prefixIcon: Icon(Icons.place_outlined)),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descricao,
                  decoration: const InputDecoration(labelText: 'Agenda / Detalhes', hintText: 'O que será discutido, programação...'),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visível para apoiadores'),
                  subtitle: const Text('Apoiadores da cidade receberão o aviso de visita.'),
                  value: _visivelApoiadores,
                  onChanged: (v) => setState(() => _visivelApoiadores = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _loading ? null : _salvar,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existente != null ? 'Salvar' : 'Agendar'),
        ),
      ],
    );
  }
}

