import 'package:flutter/material.dart';

/// Envolve [child] em um [RepaintBoundary] com [captureKey], permitindo que
/// o motor gráfico ([GraphicsEngine]) capture esta área como imagem.
class CapturableWidget extends StatelessWidget {
  const CapturableWidget({
    super.key,
    required this.captureKey,
    required this.child,
  });

  /// Key passado para o [RepaintBoundary]. Use o mesmo key em [GraphicsEngine.captureWidget].
  final GlobalKey captureKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: captureKey,
      child: child,
    );
  }
}
