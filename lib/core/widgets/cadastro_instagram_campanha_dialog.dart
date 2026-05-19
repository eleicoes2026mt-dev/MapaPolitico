import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../features/auth/helpers/salvar_meu_link_instagram_campanha.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/meu_instagram_campanha_provider.dart';

/// Ícone estilo Instagram (gradiente + câmera), sem dependência de pacote de marcas.
class InstagramGlyphIcon extends StatelessWidget {
  const InstagramGlyphIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFF58529),
          Color(0xFFDD2A7B),
          Color(0xFF8134AF),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(bounds),
      child: Icon(Icons.camera_alt_rounded, size: size),
    );
  }
}

Future<void> registrarSnoozeInstagramPrompt(String profileId) async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  await prefs.setString('$kInstagramPromptSnoozePrefix$profileId', today);
}

Future<void> showCadastroInstagramCampanhaDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialLink,
}) async {
  final ctrl = TextEditingController(text: initialLink ?? '');

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Row(
          children: [
            const InstagramGlyphIcon(size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text('Seu Instagram', style: Theme.of(ctx).textTheme.titleLarge)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cadastre seu perfil para a campanha divulgar você nas redes. '
                'Você pode preencher agora ou usar o ícone ao lado do QR no topo.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Instagram (opcional)',
                  hintText: 'https://instagram.com/… ou @usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                textInputAction: TextInputAction.done,
                autocorrect: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final p = ref.read(profileProvider).valueOrNull;
              if (p != null) await registrarSnoozeInstagramPrompt(p.id);
              if (ctx.mounted) Navigator.pop(ctx, false);
            },
            child: const Text('Depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );

  if (ok != true || !context.mounted) {
    ctrl.dispose();
    return;
  }

  try {
    await salvarMeuLinkInstagramCampanha(ref, ctrl.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instagram salvo. Obrigado!')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  } finally {
    ctrl.dispose();
  }
}
