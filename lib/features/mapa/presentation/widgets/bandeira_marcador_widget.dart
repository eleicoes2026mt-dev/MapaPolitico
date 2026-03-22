import 'package:flutter/material.dart';
import '../../../../models/bandeira_visual.dart';

/// Marcador circular da bandeira do apoiador (mapa web / preview).
class BandeiraMarcadorWidget extends StatelessWidget {
  const BandeiraMarcadorWidget({
    super.key,
    required this.visual,
    required this.tamanho,
    this.fallbackIniciais = '?',
  });

  final BandeiraVisual visual;
  final double tamanho;
  final String fallbackIniciais;

  @override
  Widget build(BuildContext context) {
    final c1 = corDeHex(visual.corPrimariaHex);
    final c2 = corDeHex(visual.corSecundariaHex);
    final emoji = visual.emoji?.trim();
    final rawIni = visual.iniciais?.trim() ?? '';
    final ini = rawIni.isNotEmpty
        ? rawIni.substring(0, rawIni.length > 3 ? 3 : rawIni.length)
        : (fallbackIniciais.trim().isNotEmpty ? fallbackIniciais.trim().substring(0, 1) : '?');

    final est = visual.iniciaisEstilo;
    final corLetra = corDeHex(est.corLetraHex, Colors.white);
    final bordaCor = corDeHex(est.bordaCorHex, Colors.black);
    final sombraCor = corDeHex(est.sombraCorHex, Colors.black54);

    Widget fundo() {
      switch (visual.layout) {
        case BandeiraFundoLayout.solidPrimary:
          return Container(color: c1);
        case BandeiraFundoLayout.solidSecondary:
          return Container(color: c2);
        case BandeiraFundoLayout.splitLeftRight:
          return Row(
            children: [
              Expanded(child: Container(color: c1)),
              Expanded(child: Container(color: c2)),
            ],
          );
        case BandeiraFundoLayout.splitTopBottom:
          return Column(
            children: [
              Expanded(child: Container(color: c1)),
              Expanded(child: Container(color: c2)),
            ],
          );
        case BandeiraFundoLayout.gradientHorizontal:
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c1, c2],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          );
        case BandeiraFundoLayout.gradientVertical:
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c1, c2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          );
      }
    }

    final sombras = <Shadow>[];
    if (est.sombraAtiva) {
      sombras.add(
        Shadow(
          color: sombraCor.withValues(alpha: 0.55),
          blurRadius: 3,
          offset: const Offset(1, 1),
        ),
      );
    }

    final baseFont = tamanho * 0.36;
    final w = est.negrito ? FontWeight.w800 : FontWeight.w500;
    final textoComBorda = est.bordaAtiva
        ? Stack(
            alignment: Alignment.center,
            children: [
              Text(
                ini,
                style: TextStyle(
                  fontSize: baseFont,
                  fontWeight: w,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = est.bordaLargura.clamp(0.5, 4)
                    ..color = bordaCor,
                ),
              ),
              Text(
                ini,
                style: TextStyle(
                  color: corLetra,
                  fontSize: baseFont,
                  fontWeight: w,
                  shadows: sombras,
                ),
              ),
            ],
          )
        : Text(
            ini,
            style: TextStyle(
              color: corLetra,
              fontSize: baseFont,
              fontWeight: w,
              shadows: sombras,
            ),
          );

    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            fundo(),
            if (emoji != null && emoji.isNotEmpty)
              Center(
                child: Text(emoji, style: TextStyle(fontSize: tamanho * 0.48)),
              )
            else
              Center(child: textoComBorda),
          ],
        ),
      ),
    );
  }
}
