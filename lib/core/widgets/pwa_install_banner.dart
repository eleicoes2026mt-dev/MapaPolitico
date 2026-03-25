import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pwa_service.dart';
import '../services/push_subscription_service.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Banner/card de instalação PWA + toggle de notificações.
/// Exibir em qualquer tela (ex.: Configurações ou Dashboard).
class PwaInstallBanner extends ConsumerStatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  ConsumerState<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends ConsumerState<PwaInstallBanner> {
  bool _canInstall = false;
  bool _isInstalled = false;
  bool _installing = false;
  bool _pushLoading = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _refresh();
      PwaService.instance.onInstallAvailable.listen((_) {
        if (mounted) _refresh();
      });
    }
  }

  void _refresh() {
    setState(() {
      _canInstall = PwaService.instance.canInstall;
      _isInstalled = PwaService.instance.isInstalled;
    });
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    final result = await PwaService.instance.install();
    if (mounted) {
      setState(() {
        _installing = false;
        _canInstall = PwaService.instance.canInstall;
        _isInstalled = PwaService.instance.isInstalled;
      });
      if (result == 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App instalado! Acesse pelo ícone na tela inicial.')),
        );
      }
    }
  }

  Future<void> _togglePush(bool enable, String profileId) async {
    setState(() => _pushLoading = true);
    if (enable) {
      final result = await PushSubscriptionService.instance.enablePush(profileId);
      if (mounted) {
        final msg = switch (result) {
          PushSubscribeResult.granted => 'Notificações ativadas!',
          PushSubscribeResult.alreadySubscribed => 'Notificações já estavam ativas.',
          PushSubscribeResult.denied =>
            'Permissão negada. Ative nas configurações do browser.',
          PushSubscribeResult.unsupported =>
            'Notificações push não configuradas (falta VAPID key).',
          PushSubscribeResult.error => 'Erro ao ativar notificações.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } else {
      await PushSubscriptionService.instance.disablePush(profileId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Notificações desativadas.')));
      }
    }
    if (mounted) {
      setState(() => _pushLoading = false);
      ref.invalidate(pushEnabledProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final pushAsync = ref.watch(pushEnabledProvider);
    final pushEnabled = pushAsync.valueOrNull ?? false;

    final showInstall = _canInstall && !_isInstalled;
    final showPush = profile != null;

    if (!showInstall && !showPush) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smartphone, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'App & Notificações',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Instalar como app ──────────────────────────────────────────
            if (showInstall) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.install_mobile_outlined),
                title: const Text('Instalar como aplicativo'),
                subtitle: const Text(
                  'Adiciona à tela inicial — funciona como um app nativo, sem precisar abrir o browser.',
                ),
                trailing: _installing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _install,
                        child: const Text('Instalar'),
                      ),
              ),
              const Divider(height: 24),
            ],

            if (_isInstalled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
                title: const Text('App instalado'),
                subtitle: const Text('Você está acessando pelo app instalado.'),
              ),

            if (_isInstalled) const Divider(height: 24),

            // ── Notificações push ──────────────────────────────────────────
            if (showPush)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  pushEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                ),
                title: const Text('Notificações'),
                subtitle: Text(
                  pushEnabled
                      ? 'Você receberá alertas mesmo com o browser fechado.'
                      : 'Ative para receber alertas de mensagens e atualizações.',
                ),
                trailing: _pushLoading || pushAsync.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: pushEnabled,
                        onChanged: (v) => _togglePush(v, profile.id),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
