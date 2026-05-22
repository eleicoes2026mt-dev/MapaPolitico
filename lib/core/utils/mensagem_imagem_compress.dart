import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Mantém apenas o centro (quadrado) da imagem, para aparecer bem em cartões quadrados.
img.Image recortarQuadradoCentral(img.Image frame) {
  final w = frame.width;
  final h = frame.height;
  if (w == h) return frame;
  final side = w < h ? w : h;
  final left = ((w - side) ~/ 2).clamp(0, w - 1);
  final top = ((h - side) ~/ 2).clamp(0, h - 1);
  return img.copyCrop(frame, x: left, y: top, width: side, height: side);
}

/// Redimensiona (lado máximo), opcionalmente **recorta quadrado pelo centro** e gera JPEG
/// adequado ao envio das mensagens.
/// Use [recorteQuadradoCentralAutomatico] apenas quando já entrou pelo editor de recorte manual.
Uint8List comprimirImagemParaMensagem(
  Uint8List raw, {
  bool recorteQuadradoCentralAutomatico = true,
}) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw const FormatException(
      'Não foi possível ler a imagem. Use JPG ou PNG.',
    );
  }

  img.Image frame = decoded;
  const maxSide = 1120;
  if (frame.width > maxSide || frame.height > maxSide) {
    if (frame.width >= frame.height) {
      frame =
          img.copyResize(frame, width: maxSide, interpolation: img.Interpolation.linear);
    } else {
      frame =
          img.copyResize(frame, height: maxSide, interpolation: img.Interpolation.linear);
    }
  }

  if (recorteQuadradoCentralAutomatico) {
    frame = recortarQuadradoCentral(frame);
  }

  Uint8List out = Uint8List.fromList(img.encodeJpg(frame, quality: 82));

  // Se ainda passar ~450 KB após primeiro passo, reduz mais a qualidade.
  for (var q = 72; q >= 58 && out.length > 450 * 1024; q -= 6) {
    out = Uint8List.fromList(img.encodeJpg(frame, quality: q));
  }

  return out;
}
