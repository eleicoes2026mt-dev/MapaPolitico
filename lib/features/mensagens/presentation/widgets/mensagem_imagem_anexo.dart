import 'dart:math' show min;

import 'package:flutter/material.dart';

/// Lado máximo (dp) do quadrado nos cartões e na pré-visualização do formulário.
const kMensagemImagemListaLadoDp = 220.0;

/// Pré-visualização quadrada da imagem da mensagem (toque amplia).
class MensagemImagemAnexo extends StatelessWidget {
  const MensagemImagemAnexo({
    super.key,
    required this.imagemUrl,
    this.maxLadoLista = kMensagemImagemListaLadoDp,
  });

  final String imagemUrl;
  /// Lado máximo do quadrado; em ecrãs estreitos usa a largura disponível.
  final double maxLadoLista;

  Uri? get _uri => Uri.tryParse(imagemUrl.trim());

  void _abrirAmpliado(BuildContext context) {
    final u = _uri;
    if (u == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.78;
        final w = MediaQuery.sizeOf(ctx).width * 0.92;
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            height: h,
            width: w,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(imagemUrl, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _uri;
    if (u == null || !u.hasScheme) return const SizedBox.shrink();

    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avail = constraints.maxWidth.isFinite ? constraints.maxWidth : maxLadoLista;
          if (avail <= 0) return const SizedBox.shrink();
          final side = min(avail, maxLadoLista);
          final pix = ((side * dpr)).round().clamp(1, 8192);

          return Align(
            alignment: Alignment.center,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _abrirAmpliado(context),
              child: SizedBox(
                height: side,
                width: side,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    child: Image.network(
                      imagemUrl,
                      fit: BoxFit.cover,
                      cacheWidth: pix,
                      cacheHeight: pix,
                      errorBuilder: (_, __, ___) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes!)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
