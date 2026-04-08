import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/env_config.dart';
import '../../../core/geo/lat_lng.dart' as app_geo;
import '../../../core/services/cep_br_service.dart';
import '../../../core/services/google_places_service.dart';
import '../../../core/services/maps_navigation_service.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/municipio.dart';
import '../../../models/visita.dart';
import '../../apoiadores/presentation/utils/apoiadores_form_utils.dart'
    show CepInputFormatter, cepSoDigitos, formatCepDisplayFromDigits;
import '../../apoiadores/providers/apoiadores_provider.dart' show apoiadoresListProvider;
import '../../assessores/providers/assessores_provider.dart' show assessoresListProvider;
import '../../auth/providers/auth_provider.dart';
import '../../votantes/providers/votantes_provider.dart' show municipiosMTListProvider, refreshMunicipiosMTList;
import '../../mapa/data/mt_municipios_coords.dart' show getCoordsMunicipioMT;
import '../providers/agenda_provider.dart';
import 'agenda_map_picker_sheet.dart';
import 'agenda_municipio_picker_sheet.dart';

/// Alcance do push ao notificar visita pública com cidade definida.
enum _AlcancePushVisita { todos, moradoresCidade }

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime _mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _diaSelecionado;
  final Set<String> _presencaIgnorados = {};
  bool _presencaDialogEmExibicao = false;

  Future<void> _mostrarDialogPresenca(Visita v) async {
    if (!mounted || _presencaDialogEmExibicao) return;
    if (_presencaIgnorados.contains(v.id)) return;
    _presencaDialogEmExibicao = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar presença'),
        content: Text(
          'Confirma presença na visita "${v.titulo}" (${v.dataHoraFormatada})'
          '${v.municipioNome != null ? ' em ${v.municipioNome}.' : '.'}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _presencaIgnorados.add(v.id);
              Navigator.pop(ctx);
            },
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await supabase.rpc('registrar_presenca_visita', params: {'p_reuniao_id': v.id});
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Presença registrada. Obrigado!')),
                  );
                }
                ref.invalidate(visitaPendenteConfirmacaoProvider);
                ref.invalidate(visitasProvider);
                ref.invalidate(proximaVisitaMinhaCidadeProvider);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Não foi possível confirmar: $e')),
                  );
                }
              }
            },
            child: const Text('Confirmar presença'),
          ),
        ],
      ),
    );
    _presencaDialogEmExibicao = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeEditar = profile?.role == 'candidato' || profile?.role == 'assessor';
    final isApoiador = profile?.role == 'apoiador';
    final isAssessor = profile?.role == 'assessor';

    ref.listen<AsyncValue<Visita?>>(visitaPendenteConfirmacaoProvider, (prev, next) {
      next.whenData((v) {
        if (v == null) return;
        if (_presencaIgnorados.contains(v.id)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarDialogPresenca(v));
      });
    });

    final visitasAsync = podeEditar
        ? ref.watch(todasVisitasProvider)
        : ref.watch(visitasProvider);

    final proximaAsync = isApoiador ? ref.watch(proximaVisitaMinhaCidadeProvider) : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(visitasProvider);
        ref.invalidate(todasVisitasProvider);
        ref.invalidate(proximaVisitaMinhaCidadeProvider);
        ref.invalidate(visitaPendenteConfirmacaoProvider);
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calendar_month_rounded, size: 36, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agenda de Visitas',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        podeEditar
                            ? 'Organize visitas por cidade — notificações públicas ou apenas para quem você escolher.'
                            : 'Próximas visitas do deputado à sua cidade.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const EstadoMTBadge(compact: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
            Text(
              'Calendário',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () => _abrirFormulario(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova visita'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Visitas',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

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
                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_note_rounded,
                          size: 56,
                          color: theme.colorScheme.primary.withValues(alpha: 0.55),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _diaSelecionado != null
                              ? 'Nenhuma visita neste dia'
                              : 'Nenhuma visita agendada',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _diaSelecionado != null
                              ? 'Escolha outro dia no calendário ou limpe o filtro.'
                              : (podeEditar
                                  ? 'Crie uma visita para aparecer no calendário e notificar apoiadores ou uma lista fechada.'
                                  : 'Quando houver visitas à sua cidade, elas aparecerão aqui.'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
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
                  mostrarRotas: isApoiador || isAssessor,
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
    final privada = v.notificacaoProfileIds.isNotEmpty;
    final temCidade = v.municipioId != null && v.municipioId!.trim().isNotEmpty;

    _AlcancePushVisita? alcance;
    if (!privada && temCidade) {
      alcance = await showDialog<_AlcancePushVisita>(
        context: context,
        builder: (ctx) {
          var sel = _AlcancePushVisita.moradoresCidade;
          return StatefulBuilder(
            builder: (ctx, setSt) {
              return AlertDialog(
                title: const Text('Enviar notificação'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Visita em ${v.municipioNome ?? "município"}.',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      RadioListTile<_AlcancePushVisita>(
                        title: const Text('Apenas moradores desta cidade'),
                        subtitle: const Text(
                          'Apoiadores e votantes com conta no app e município igual ao da visita.',
                        ),
                        value: _AlcancePushVisita.moradoresCidade,
                        groupValue: sel,
                        onChanged: (x) => setSt(() => sel = x!),
                      ),
                      RadioListTile<_AlcancePushVisita>(
                        title: const Text('Todos com notificações ativas'),
                        subtitle: const Text('Toda a base inscrita em push na campanha.'),
                        value: _AlcancePushVisita.todos,
                        groupValue: sel,
                        onChanged: (x) => setSt(() => sel = x!),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, sel),
                    child: const Text('Notificar'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (alcance == null || !mounted) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enviar notificação'),
          content: Text(
            privada
                ? 'Enviar push apenas aos ${v.notificacaoProfileIds.length} destinatário(s) desta agenda privada (${v.municipioNome ?? v.titulo})?'
                : 'Sem cidade definida nesta visita — a notificação será enviada a todos com push ativado. Continuar?',
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
      alcance = _AlcancePushVisita.todos;
    }

    try {
      await supabase.auth.refreshSession();
      final body = <String, dynamic>{
        'title': '📅 Visita: ${v.municipioNome ?? v.titulo}',
        'body':
            'O deputado visitará ${v.municipioNome ?? "sua cidade"} em ${v.dataHoraFormatada}.'
            '${v.localTexto != null ? " Local: ${v.localTexto}" : ""}',
        'url': '/#/agenda',
        'tag': 'visita-${v.id}',
      };
      if (privada) {
        body['profileIds'] = v.notificacaoProfileIds;
      } else if (!privada &&
          temCidade &&
          alcance == _AlcancePushVisita.moradoresCidade) {
        final ids = await profileIdsMoradoresCidadeComConta(v.municipioId!);
        if (ids.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nenhum apoiador ou votante com conta neste município. Ajuste o cadastro ou use «Todos».',
              ),
              duration: Duration(seconds: 6),
            ),
          );
          return;
        }
        body['profileIds'] = ids;
      }
      final r = await supabase.functions.invoke('send-push', body: body);

      if (r.status >= 400) {
        final detail = r.data is Map ? (r.data as Map)['error'] ?? r.data.toString() : r.data?.toString() ?? '';
        throw Exception('Erro ${r.status}: $detail');
      }

      await supabase
          .from('reunioes')
          .update({'notificados_em': DateTime.now().toIso8601String()})
          .eq('id', v.id);
      ref.invalidate(visitasProvider);
      ref.invalidate(todasVisitasProvider);

      if (!mounted) return;
      final data = r.data is Map<String, dynamic> ? r.data as Map<String, dynamic> : null;
      final sent = data?['sent'] ?? 0;
      final total = data?['total'] ?? 0;
      final msg2 = total == 0
          ? 'Enviado! Nenhum dispositivo inscrito ainda.\nVá em Configurações → ative Notificações.'
          : 'Notificação enviada para $sent de $total dispositivos.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg2), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('Erro ao notificar:\n${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: const Duration(seconds: 8),
          // placeholder para o restante do catch
          // ignore
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
    required this.mostrarRotas,
    required this.onEdit,
    required this.onDelete,
    required this.onNotificar,
  });

  final Visita visita;
  final bool podeEditar;
  final bool mostrarRotas;
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
                          if (visita.agendaPrivada) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 12, color: theme.colorScheme.onTertiaryContainer),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Privada',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onTertiaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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
                      if (visita.horaExibicao.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(visita.horaExibicao, style: theme.textTheme.bodySmall),
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
                      if (mostrarRotas) ...[
                        const SizedBox(height: 10),
                        _RotasVisitaBar(visita: visita),
                      ],
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
                      PopupMenuItem(
                        value: 'notify',
                        child: ListTile(
                          leading: const Icon(Icons.notifications_active_outlined),
                          title: Text(
                            visita.notificacaoProfileIds.isEmpty ? 'Notificar todos' : 'Notificar destinatários',
                          ),
                        ),
                      ),
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

class _RotasVisitaBar extends StatelessWidget {
  const _RotasVisitaBar({required this.visita});
  final Visita visita;

  Future<void> _abrirGoogle(BuildContext context) async {
    if (visita.localLat != null && visita.localLng != null) {
      final ok = await openGoogleMapsDestination(
        lat: visita.localLat!,
        lng: visita.localLng!,
      );
      if (!context.mounted || ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Google Maps.')),
      );
      return;
    }
    final partes = <String>[
      if (visita.localTexto != null && visita.localTexto!.trim().isNotEmpty) visita.localTexto!.trim(),
      if (visita.municipioNome != null && visita.municipioNome!.trim().isNotEmpty) visita.municipioNome!.trim(),
      'MT',
    ];
    if (partes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem endereço ou coordenadas para abrir o mapa.')),
      );
      return;
    }
    final ok = await openGoogleMapsSearchQuery(partes.join(', '));
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o Google Maps.')),
    );
  }

  Future<void> _abrirWaze(BuildContext context) async {
    if (visita.localLat == null || visita.localLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Waze precisa das coordenadas do ponto. Peça ao candidato para marcar o local no mapa ao agendar a visita.',
          ),
        ),
      );
      return;
    }
    final ok = await openWazeDestination(lat: visita.localLat!, lng: visita.localLng!);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o Waze.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed: () => _abrirGoogle(context),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Google Maps'),
        ),
        OutlinedButton.icon(
          onPressed: () => _abrirWaze(context),
          icon: const Icon(Icons.navigation_outlined, size: 18),
          label: const Text('Waze'),
        ),
      ],
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
                const SizedBox(height: 12),
                _RotasVisitaBar(visita: visita),
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

TimeOfDay? _parseHoraVisita(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(':');
  final h = int.tryParse(parts[0].trim());
  if (h == null) return null;
  final m = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
  return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
}

String? _horaVisitaParaSalvar(TimeOfDay? t) {
  if (t == null) return null;
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _VisitaFormDialogState extends ConsumerState<_VisitaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _local;
  late final TextEditingController _descricao;
  final _localFocus = FocusNode();
  DateTime? _data;
  TimeOfDay? _horaTd;
  String? _municipioIdSelecionado;
  double? _localLat;
  double? _localLng;
  /// Se true, a visita não aparece para todos os apoiadores; só [destinatarios] recebem push e veem na agenda.
  bool _agendaPrivada = false;
  /// Visita pública com cidade: ao agendar, push só para contas (apoiador/votante) neste município.
  bool _pushApenasMoradoresDaCidade = false;
  final Set<String> _destProfileIds = {};
  bool _loading = false;
  Timer? _placesDebounce;
  List<PlacePrediction> _sugestoesPlaces = [];
  bool _placesCarregando = false;
  late final String _placesSessionToken;

  void _onLocalFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _localFocus.addListener(_onLocalFocusChanged);
    _placesSessionToken =
        '${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this)}';
    final v = widget.existente;
    _titulo = TextEditingController(text: v?.titulo ?? '');
    _local = TextEditingController(text: v?.localTexto ?? '');
    _descricao = TextEditingController(text: v?.descricao ?? '');
    _horaTd = _parseHoraVisita(v?.hora);
    _data = v?.dataReuniao;
    _municipioIdSelecionado = v?.municipioId;
    _agendaPrivada = v != null ? !v.visivelApoiadores : false;
    _pushApenasMoradoresDaCidade = false;
    _destProfileIds
      ..clear()
      ..addAll(v?.notificacaoProfileIds ?? const []);
    _localLat = v?.localLat;
    _localLng = v?.localLng;
    _local.addListener(_onLocalTextChanged);
  }

  void _onLocalTextChanged() {
    _placesDebounce?.cancel();
    final text = _local.text.trim();
    if (text.length < 3) {
      if (_sugestoesPlaces.isNotEmpty) setState(() => _sugestoesPlaces = []);
      return;
    }
    if (EnvConfig.googleMapsApiKey.trim().isEmpty) return;
    _placesDebounce = Timer(const Duration(milliseconds: 420), () async {
      if (!mounted) return;
      setState(() => _placesCarregando = true);
      GooglePlacesMunicipioContext? ctx;
      final mid = _municipioIdSelecionado;
      if (mid != null) {
        final munList = ref.read(municipiosMTListProvider).valueOrNull;
        if (munList != null) {
          for (final m in munList) {
            if (m.id == mid) {
              final c = getCoordsMunicipioMT(m.nome);
              if (c != null) {
                ctx = GooglePlacesMunicipioContext(
                  centerLat: c.latitude,
                  centerLng: c.longitude,
                  municipioNome: m.nome,
                );
              }
              break;
            }
          }
        }
      }
      final list = await fetchGooglePlacePredictions(
        text,
        sessionToken: _placesSessionToken,
        municipioContext: ctx,
      );
      if (!mounted) return;
      setState(() {
        _placesCarregando = false;
        _sugestoesPlaces = list.take(8).toList();
      });
    });
  }

  @override
  void dispose() {
    _placesDebounce?.cancel();
    _local.removeListener(_onLocalTextChanged);
    _localFocus.removeListener(_onLocalFocusChanged);
    _titulo.dispose();
    _local.dispose();
    _descricao.dispose();
    _localFocus.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_data == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a data.')));
      return;
    }
    if (_agendaPrivada && _destProfileIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na agenda privada, selecione pelo menos um assessor ou apoiador.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final params = NovaVisitaParams(
        titulo: _titulo.text.trim(),
        dataReuniao: _data!,
        hora: _horaVisitaParaSalvar(_horaTd),
        localTexto: _local.text.trim().isEmpty ? null : _local.text.trim(),
        localLat: _localLat,
        localLng: _localLng,
        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        municipioId: _municipioIdSelecionado,
        visivelApoiadores: !_agendaPrivada,
        notificacaoProfileIds: _agendaPrivada ? _destProfileIds.toList() : const [],
        pushApenasMoradoresDaCidade:
            !_agendaPrivada && _pushApenasMoradoresDaCidade && _municipioIdSelecionado != null,
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

  Future<void> _selecionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaTd ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _horaTd = picked);
  }

  String _rotuloCidade(List<Municipio> municipios) {
    if (_municipioIdSelecionado == null) return 'Sem cidade específica';
    for (final m in municipios) {
      if (m.id == _municipioIdSelecionado) return m.nome;
    }
    return 'Município selecionado';
  }

  Future<void> _abrirPickerCidade(List<Municipio> municipios) async {
    final res = await showAgendaMunicipioPickerSheet(
      context,
      municipios: municipios,
      municipioIdSelecionado: _municipioIdSelecionado,
    );
    if (!mounted || res == null) return;
    setState(() => _municipioIdSelecionado = res.municipioId);
    if (!res.openMapPicker || res.municipioId == null) return;

    Municipio? mun;
    for (final m in municipios) {
      if (m.id == res.municipioId) {
        mun = m;
        break;
      }
    }
    if (mun == null || !mounted) return;

    final coords = getCoordsMunicipioMT(mun.nome);
    final center = coords != null
        ? app_geo.LatLng(coords.latitude, coords.longitude)
        : const app_geo.LatLng(-15.6014, -56.0979);

    final mapRes = await showAgendaMapPickerSheet(
      context,
      initialCenter: center,
      municipioNome: mun.nome,
      searchBiasSuffix: ', ${mun.nome}, MT, Brasil',
      initialSearchText: _local.text.trim().isEmpty ? null : _local.text.trim(),
    );
    if (mounted && mapRes != null && mapRes.addressLabel.trim().isNotEmpty) {
      setState(() {
        _local.text = mapRes.addressLabel.trim();
        _localLat = mapRes.lat;
        _localLng = mapRes.lng;
      });
    }
  }

  Future<void> _buscarPorCep() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buscar endereço por CEP'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'CEP',
            hintText: '00000-000',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [CepInputFormatter()],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buscar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final d = cepSoDigitos(ctrl.text);
    ctrl.dispose();
    if (d.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CEP inválido.')));
      return;
    }
    final r = await fetchCepBr(d);
    if (!mounted) return;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CEP não encontrado.')));
      return;
    }
    final linha = [
      if (r.logradouro.isNotEmpty) r.logradouro,
      if (r.bairro != null && r.bairro!.isNotEmpty) r.bairro,
      '${r.localidade} — ${r.uf}',
      if (formatCepDisplayFromDigits(r.cep).isNotEmpty) 'CEP ${formatCepDisplayFromDigits(r.cep)}',
    ].join(', ');
    setState(() {
      _local.text = linha;
      _sugestoesPlaces = [];
      _localLat = null;
      _localLng = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _aplicarSugestaoPlace(PlacePrediction p) async {
    setState(() => _placesCarregando = true);
    final d = await fetchGooglePlaceDetailsLatLng(p.placeId);
    if (!mounted) return;
    setState(() {
      _placesCarregando = false;
      _local.text = (d != null ? d.primaryLabel : p.description).trim();
      _localLat = d?.lat;
      _localLng = d?.lng;
      _sugestoesPlaces = [];
    });
    _localFocus.unfocus();
  }

  Future<void> _abrirDestinatariosDialog() async {
    final theme = Theme.of(context);
    final assessores = await ref.read(assessoresListProvider.future);
    final apoiadores = await ref.read(apoiadoresListProvider.future);
    if (!mounted) return;
    final local = Set<String>.from(_destProfileIds);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Destinatários da agenda privada'),
            content: SizedBox(
              width: 440,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assessores',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...assessores.where((a) => a.ativo).map(
                          (a) => CheckboxListTile(
                            dense: true,
                            value: local.contains(a.profileId),
                            onChanged: (sel) => setLocal(() {
                              if (sel == true) {
                                local.add(a.profileId);
                              } else {
                                local.remove(a.profileId);
                              }
                            }),
                            title: Text(a.nome),
                          ),
                        ),
                    const SizedBox(height: 16),
                    Text(
                      'Apoiadores (com conta no app)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final comConta =
                            apoiadores.where((a) => a.profileId != null && a.profileId!.isNotEmpty).toList();
                        if (comConta.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Nenhum apoiador com login vinculado.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final a in comConta)
                              CheckboxListTile(
                                dense: true,
                                value: local.contains(a.profileId!),
                                onChanged: (sel) => setLocal(() {
                                  if (sel == true) {
                                    local.add(a.profileId!);
                                  } else {
                                    local.remove(a.profileId!);
                                  }
                                }),
                                title: Text(a.nome),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _destProfileIds
                      ..clear()
                      ..addAll(local);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Concluir'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _abrirMapaSelecionarLocal(List<Municipio> municipios) async {
    var center = const app_geo.LatLng(-15.6014, -56.0979);
    var nomeContexto = 'Mato Grosso';
    var bias = ', Mato Grosso, Brasil';
    if (_municipioIdSelecionado != null) {
      for (final m in municipios) {
        if (m.id == _municipioIdSelecionado) {
          nomeContexto = m.nome;
          final c = getCoordsMunicipioMT(m.nome);
          if (c != null) center = app_geo.LatLng(c.latitude, c.longitude);
          bias = ', ${m.nome}, MT, Brasil';
          break;
        }
      }
    }
    final res = await showAgendaMapPickerSheet(
      context,
      initialCenter: center,
      municipioNome: nomeContexto,
      searchBiasSuffix: bias,
      initialSearchText: _local.text.trim().isEmpty ? null : _local.text.trim(),
    );
    if (mounted && res != null && res.addressLabel.trim().isNotEmpty) {
      setState(() {
        _local.text = res.addressLabel.trim();
        _localLat = res.lat;
        _localLng = res.lng;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final munAsync = ref.watch(municipiosMTListProvider);
    final temPlacesKey = EnvConfig.googleMapsApiKey.trim().isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.event_available_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.existente != null ? 'Editar visita' : 'Nova visita'),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titulo,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),
                Text('Data e horário', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _selecionarData,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data *',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _data != null ? DateFormat('dd/MM/yyyy').format(_data!) : 'Selecionar',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _selecionarHora,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Horário',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              suffixIcon: Icon(Icons.schedule_outlined),
                            ),
                            child: Text(
                              _horaTd != null
                                  ? '${_horaTd!.hour.toString().padLeft(2, '0')}:${_horaTd!.minute.toString().padLeft(2, '0')}'
                                  : 'Selecionar',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Horário opcional • seletor em formato 24 horas.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (_horaTd != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _horaTd = null),
                      child: const Text('Remover horário'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Cidade', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                munAsync.when(
                  data: (municipios) {
                    final ordenados = List<Municipio>.from(municipios)
                      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                    if (ordenados.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Material(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              leading: Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
                              title: const Text('Municípios MT não disponíveis'),
                              subtitle: Text(
                                'O catálogo não carregou do servidor. Toque em «Tentar novamente» ou confira no Supabase se a tabela municipios tem linhas e políticas de leitura.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                    return Material(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: const Icon(Icons.location_city_outlined),
                        title: Text(_rotuloCidade(ordenados)),
                        subtitle: const Text('Toque para buscar na lista A–Z'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrirPickerCidade(ordenados),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Erro ao carregar municípios', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await refreshMunicipiosMTList(ref);
                          if (context.mounted) setState(() {});
                        },
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Local do encontro', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  temPlacesKey
                      ? 'Digite no campo ou use «Escolher no mapa» para buscar o lugar e marcar o ponto.'
                      : 'Sem chave Google, a busca no mapa usa OpenStreetMap. CEP continua disponível.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _local,
                  focusNode: _localFocus,
                  decoration: InputDecoration(
                    labelText: 'Endereço, ponto de referência ou estabelecimento',
                    hintText: 'Ex.: Rua Principal ou nome do comércio',
                    prefixIcon: const Icon(Icons.place_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: _placesCarregando
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_sugestoesPlaces.isNotEmpty && _localFocus.hasFocus)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _sugestoesPlaces.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _sugestoesPlaces[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.location_searching, size: 20, color: theme.colorScheme.primary),
                              title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _aplicarSugestaoPlace(p),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _buscarPorCep,
                      icon: const Icon(Icons.pin_outlined, size: 18),
                      label: const Text('Buscar por CEP'),
                    ),
                    munAsync.maybeWhen(
                      data: (municipios) => OutlinedButton.icon(
                        onPressed: () => _abrirMapaSelecionarLocal(municipios),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Escolher no mapa'),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descricao,
                  decoration: const InputDecoration(
                    labelText: 'Agenda / detalhes',
                    hintText: 'O que será discutido, programação…',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _agendaPrivada ? Icons.lock_outline_rounded : Icons.public_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Agenda privada'),
                  subtitle: Text(
                    _agendaPrivada
                        ? 'Apenas os destinatários escolhidos recebem notificação e veem esta visita na agenda.'
                        : 'Visita visível para apoiadores da cidade (padrão).',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: Switch(
                    value: _agendaPrivada,
                    onChanged: (v) => setState(() {
                      _agendaPrivada = v;
                      if (!v) _destProfileIds.clear();
                    }),
                  ),
                ),
                if (_agendaPrivada) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _abrirDestinatariosDialog,
                      icon: const Icon(Icons.group_add_rounded, size: 20),
                      label: Text(
                        _destProfileIds.isEmpty
                            ? 'Selecionar assessores e apoiadores'
                            : '${_destProfileIds.length} destinatário(s) selecionado(s)',
                      ),
                    ),
                  ),
                ],
                if (!_agendaPrivada && _municipioIdSelecionado != null) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.place_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Notificação ao agendar'),
                    subtitle: Text(
                      _pushApenasMoradoresDaCidade
                          ? 'Enviar push só para apoiadores e votantes com conta neste município.'
                          : 'Enviar push para todos inscritos em notificações (toda a campanha).',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    trailing: Switch(
                      value: _pushApenasMoradoresDaCidade,
                      onChanged: (v) => setState(() => _pushApenasMoradoresDaCidade = v),
                    ),
                  ),
                ],
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
