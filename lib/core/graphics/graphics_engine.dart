import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Motor gráfico do sistema: captura de widgets em imagem e exportação (compartilhar/salvar).
/// Use [CapturableWidget] para envolver o conteúdo que será capturado e [captureWidget]
/// para gerar PNG e [shareImage] para compartilhar ou salvar.
class GraphicsEngine {
  GraphicsEngine._();

  /// Captura o widget associado a [captureKey] (deve ser o key de um [RepaintBoundary])
  /// e retorna os bytes PNG. [pixelRatio] controla a resolução (ex.: 2 = retina).
  static Future<Uint8List?> captureWidget(
    GlobalKey captureKey, {
    double pixelRatio = 2.0,
  }) async {
    final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Compartilha ou faz download da imagem [pngBytes] com [filename] (ex.: "mapa-mt.png").
  /// Em web pode disparar download; em mobile abre o sheet de compartilhamento.
  static Future<void> shareImage(Uint8List pngBytes, String filename) async {
    final xFile = XFile.fromData(
      pngBytes,
      mimeType: 'image/png',
      name: filename,
    );
    await Share.shareXFiles([xFile], text: filename);
  }

  /// Gera a imagem e já compartilha. Retorna true se sucesso.
  static Future<bool> captureAndShare(
    GlobalKey captureKey, {
    String filename = 'mapa-mt.png',
    double pixelRatio = 2.0,
  }) async {
    final bytes = await captureWidget(captureKey, pixelRatio: pixelRatio);
    if (bytes == null || bytes.isEmpty) return false;
    await shareImage(bytes, filename);
    return true;
  }
}
