import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push_subscription_service.dart';
import '../services/pwa_service.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Exibe o fluxo de onboarding PWA (instalar + notificações) na primeira visita.
/// Retorna após o usuário concluir ou pular todas as etapas.
Future<void> mostrarPwaOnboarding(BuildContext context, WidgetRef ref) async {
  if (!kIsWeb) return;
  if (PwaService.instance.hasSeenOnboarding) return;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, __) => _PwaOnboardingDialog(ref: ref),
  );
}

class _PwaOnboardingDialog extends ConsumerStatefulWidget {
  const _PwaOnboardingDialog({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_PwaOnboardingDialog> createState() => _PwaOnboardingDialogState();
}

class _PwaOnboardingDialogState extends ConsumerState<_PwaOnboardingDialog> {
  int _step = 0; // 0 = install, 1 = notifications
  bool _loading = false;
  String _notifStatus = ''; // '' | 'granted' | 'denied' | 'loading'

  final _pwa = PwaService.instance;

  @override
  void initState() {
    super.initState();
    // Se já instalado, pula direto para notificações
    if (_pwa.isInstalled) _step = 1;
    // Se notificações já concedidas, vai para a step de notificações
    if (_pwa.notificationsGranted) _notifStatus = 'granted';
  }

  Future<void> _requestNotifications() async {
    final profile = widget.ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _notifStatus = 'denied');
      return;
    }
    setState(() { _loading = true; _notifStatus = 'loading'; });
    try {
      final result = await PushSubscriptionService.instance.enablePush(profile.id);
      setState(() {
        _notifStatus = result == PushSubscribeResult.denied ? 'denied' : 'granted';
        _loading = false;
      });
    } catch (_) {
      setState(() { _notifStatus = 'denied'; _loading = false; });
    }
  }

  void _concluir() {
    PwaService.instance.markOnboardingSeen();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 500;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isNarrow ? size.width : 460,
          maxHeight: size.height * 0.92,
        ),
        child: Material(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.how_to_vote, size: 38, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CampanhaMT',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestão Eleitoral · Mato Grosso',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Indicador de passos
                  _StepIndicator(currentStep: _step, totalSteps: 2),
                  const SizedBox(height: 24),

                  // Conteúdo do passo atual
                  if (_step == 0) _buildInstallStep(theme) else _buildNotifStep(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Passo 1: Instalar ─────────────────────────────────────────────────────

  Widget _buildInstallStep(ThemeData theme) {
    final isInstalled = _pwa.isInstalled;
    final isIOSSafari = _pwa.isIOS && _pwa.isSafari;

    // Já instalado → avança direto
    if (isInstalled) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) setState(() => _step = 1); });
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Icon(Icons.install_mobile_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'Instale o app na sua tela inicial',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Acesse como um app nativo — ícone na tela inicial, sem abrir o browser.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        if (isIOSSafari) ...[
          // Safari iOS: único browser sem API de install automático
          _SafariInstallGuide(theme: theme),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('Pular'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.check),
                  label: const Text('Já instalei'),
                ),
              ),
            ],
          ),
        ] else ...[
          // Chrome / Edge / outros: um clique → o browser exibe o prompt nativo
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _instalarAgora,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
              label: Text(_loading ? 'Aguarde...' : 'Instalar o app'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: Text(
              _pwa.canInstall ? 'Pular por agora' : 'Continuar sem instalar',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _instalarAgora() async {
    setState(() => _loading = true);
    // Se o prompt ainda não está pronto, aguarda até 3s
    if (!_pwa.canInstall) {
      for (var i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_pwa.canInstall || !mounted) break;
      }
    }
    if (_pwa.canInstall) {
      await _pwa.install();
      // Aguarda o evento pwa-app-installed ou avança após 3s
      await Future.delayed(const Duration(seconds: 3));
    }
    if (mounted) setState(() { _loading = false; _step = 1; });
  }

  // ── Passo 2: Notificações ─────────────────────────────────────────────────

  Widget _buildNotifStep(ThemeData theme) {
    final granted = _notifStatus == 'granted' || _pwa.notificationsGranted;

    return Column(
      children: [
        Icon(
          granted ? Icons.notifications_active : Icons.notifications_outlined,
          size: 48,
          color: granted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Ative as notificações',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Receba alertas de visitas do deputado, aniversariantes, mensagens e atualizações — mesmo com o app fechado.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        if (granted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notificações ativadas!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _concluir,
            icon: const Icon(Icons.check),
            label: const Text('Concluir'),
          ),
        ] else if (_notifStatus == 'denied') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Permissão negada. Para ativar manualmente: clique no ícone de cadeado na barra do browser → Notificações → Permitir.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _concluir,
                  child: const Text('Continuar mesmo assim'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _requestNotifications,
                  child: const Text('Tentar novamente'),
                ),
              ),
            ],
          ),
        ] else ...[
          // Estado inicial
          _NotifBenefit(icon: Icons.event, text: 'Visitas do deputado à sua cidade'),
          const SizedBox(height: 8),
          _NotifBenefit(icon: Icons.cake_outlined, text: 'Alertas de aniversariantes'),
          _NotifBenefit(icon: Icons.chat_bubble_outline, text: 'Mensagens da campanha'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _requestNotifications,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.notifications_active),
              label: Text(_loading ? 'Aguardando...' : 'Ativar notificações'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _concluir,
            child: const Text('Pular (não recomendado)'),
          ),
        ],
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['Instalar app', 'Notificações'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        final isDone = i < currentStep;
        return Row(
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isActive
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            if (i < totalSteps - 1)
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: currentStep > i
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
              ),
          ],
        );
      }),
    );
  }
}

class _SafariInstallGuide extends StatelessWidget {
  const _SafariInstallGuide({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Como instalar no iPhone/iPad:', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _SafariStep(n: '1', icon: Icons.ios_share, text: 'Toque no botão de compartilhar (↑) na barra inferior'),
          const SizedBox(height: 8),
          _SafariStep(n: '2', icon: Icons.add_box_outlined, text: 'Selecione "Adicionar à Tela de Início"'),
          const SizedBox(height: 8),
          _SafariStep(n: '3', icon: Icons.check_circle_outline, text: 'Toque em "Adicionar" para confirmar'),
        ],
      ),
    );
  }
}

class _SafariStep extends StatelessWidget {
  const _SafariStep({required this.n, required this.icon, required this.text});
  final String n;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
          child: Center(child: Text(n, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _NotifBenefit extends StatelessWidget {
  const _NotifBenefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
