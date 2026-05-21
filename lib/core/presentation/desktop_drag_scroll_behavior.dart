import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Habilita deslizar tabelas e listas horizontais com **rato/trackpad**
/// (pressionar e arrastar), igual ao comportamento típico em folhas/web.
///
/// Por defeito, o [MaterialScrollBehavior] só arrasta assim com dedo/toque,
/// não com rato.
class DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
