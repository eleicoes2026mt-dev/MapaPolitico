import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo genérico para copiar link de convite (assessor ou apoiador).
Future<void> showConviteLinkDialog(
  BuildContext context, {
  required String link,
  required String title,
  required String description,
  String snackbarMessage = 'Link copiado.',
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.link),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              description,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackbarMessage)),
              );
            }
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar link'),
        ),
      ],
    ),
  );
}
