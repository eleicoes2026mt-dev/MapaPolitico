import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Ecrã de enquadramento: máscara **quadrado** fixo; utilizador faz zoom e arrasta a foto.
class MensagemImagemCropQuadradoScreen extends StatefulWidget {
  const MensagemImagemCropQuadradoScreen({super.key, required this.bytesOriginais});

  final Uint8List bytesOriginais;

  static Future<Uint8List?> abrir(BuildContext context, Uint8List bytes) {
    return Navigator.of(context, rootNavigator: true).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        fullscreenDialog: true,
        builder: (ctx) =>
            MensagemImagemCropQuadradoScreen(bytesOriginais: bytes),
      ),
    );
  }

  @override
  State<MensagemImagemCropQuadradoScreen> createState() =>
      _MensagemImagemCropQuadradoScreenState();
}

class _MensagemImagemCropQuadradoScreenState
    extends State<MensagemImagemCropQuadradoScreen> {
  final _controller = CropController();
  bool _processandoCrop = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    setState(() => _processandoCrop = false);

    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final cause):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível recortar: $cause')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustar enquadramento'),
        actions: [
          TextButton(
            onPressed:
                _processandoCrop ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A zona clara é o quadrado da mensagem. Arraste a foto ou use dois dedos para ampliar e afastar.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Crop(
                  image: widget.bytesOriginais,
                  controller: _controller,
                  aspectRatio: 1,
                  interactive: true,
                  fixCropRect: true,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 0.9,
                    aspectRatio: 1,
                  ),
                  baseColor:
                      theme.brightness == Brightness.dark ? const Color(0xFF181818) : Colors.white,
                  maskColor:
                      Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.55 : 0.45),
                  onCropped: _onCropped,
                  radius: 4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _processandoCrop
                      ? null
                      : () {
                          setState(() => _processandoCrop = true);
                          _controller.crop();
                        },
                  child: _processandoCrop
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Usar esta moldura'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
