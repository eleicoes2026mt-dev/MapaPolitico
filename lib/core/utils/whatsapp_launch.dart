import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/visita.dart';
import 'whatsapp_platform_stub.dart'
    if (dart.library.io) 'whatsapp_platform_io.dart' as whatsapp_platform;

/// Web ou app nativo em Windows / macOS / Linux: oferece escolher Web vs aplicativo.
bool shouldOfferWhatsAppWebOrAppChoice() =>
    kIsWeb || whatsapp_platform.isDesktopOperatingSystem();

/// Abre conversa WhatsApp com [phoneDigits] (ex.: 5565999999999) e texto [message].
/// Em PC (web ou desktop) mostra diálogo; em telemóvel usa `wa.me`.
Future<void> openWhatsAppConversation({
  required BuildContext context,
  required String phoneDigits,
  required String message,
}) async {
  if (phoneDigits.isEmpty) return;

  final encodedText = Uri.encodeComponent(message);

  if (!shouldOfferWhatsAppWebOrAppChoice()) {
    final uri = Uri.parse('https://wa.me/$phoneDigits?text=$encodedText');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  if (!context.mounted) return;

  final choice = await showDialog<_WhatsAppOpenMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Abrir WhatsApp'),
      content: const Text(
        'Como prefere abrir a conversa neste computador?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _WhatsAppOpenMode.web),
          child: const Text('WhatsApp Web'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _WhatsAppOpenMode.desktopApp),
          child: const Text('Aplicativo no PC'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );

  if (choice == null || !context.mounted) return;

  final webUri = Uri.parse(
    'https://web.whatsapp.com/send?phone=$phoneDigits&text=$encodedText',
  );

  if (choice == _WhatsAppOpenMode.web) {
    await _launchUri(webUri, context);
    return;
  }

  final appUri = Uri.parse(
    'whatsapp://send?phone=$phoneDigits&text=$encodedText',
  );

  try {
    final opened = await launchUrl(appUri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await _fallbackWebAfterAppFailed(context, webUri);
    }
  } catch (_) {
    if (context.mounted) {
      await _fallbackWebAfterAppFailed(context, webUri);
    }
  }
}

Future<void> _fallbackWebAfterAppFailed(BuildContext context, Uri webUri) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Não foi possível abrir o aplicativo. Abrindo o WhatsApp Web.',
      ),
    ),
  );
  await _launchUri(webUri, context);
}

Future<void> _launchUri(Uri uri, BuildContext context) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}

enum _WhatsAppOpenMode { web, desktopApp }

/// Usa o mesmo texto pré-preenchido que [Aniversariante.whatsappUrl].
Future<void> openWhatsAppForAniversariante(
  BuildContext context,
  Aniversariante a,
) async {
  final phone = a.telefoneWhatsappDigits;
  if (phone == null || phone.isEmpty || a.whatsappUrl.isEmpty) return;
  final parsed = Uri.parse(a.whatsappUrl);
  final text = parsed.queryParameters['text'] ?? '';
  await openWhatsAppConversation(
    context: context,
    phoneDigits: phone,
    message: text,
  );
}
